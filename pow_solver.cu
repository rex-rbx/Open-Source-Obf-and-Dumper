// sorry yes this is AI slop
// CUDA port of main.go — brute-forces the DeepSeek PoW nonce on the GPU.
// Same stdin/stdout/stderr contract as main.go: reads challenge JSON on stdin,
// prints the winning nonce on stdout, or an error on stderr with exit code 1.
//
// Build (CUDA 13.3, RTX 50-series / sm_120):
//   nvcc -O3 -arch=sm_120 -o pow_solver main.cu

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <climits>
#include <cuda_runtime.h>

#define CUDA_CHECK(expr)                                                          \
    do {                                                                          \
        cudaError_t _err = (expr);                                                \
        if (_err != cudaSuccess) {                                                \
            fprintf(stderr, "cuda error: %s\n", cudaGetErrorString(_err));        \
            exit(1);                                                              \
        }                                                                          \
    } while (0)

// ---------------------------------------------------------------------------
// Keccak-f[1600], 23 rounds (round 0 skipped) — mirrors deepseekHashV1 in main.go
// ---------------------------------------------------------------------------

__constant__ uint64_t RC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808AULL, 0x8000000080008000ULL,
    0x000000000000808BULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008AULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000AULL,
    0x000000008000808BULL, 0x800000000000008BULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800AULL, 0x800000008000000AULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL,
};

__constant__ int PI[25] = {0, 6, 12, 18, 24, 3, 9, 10, 16, 22, 1, 7, 13, 19, 20, 4, 5, 11, 17, 23, 2, 8, 14, 15, 21};
__constant__ unsigned RHO[25] = {0, 44, 43, 21, 14, 28, 20, 3, 45, 61, 1, 6, 25, 8, 18, 27, 36, 10, 15, 56, 62, 55, 39, 41, 2};

__device__ __forceinline__ uint64_t rotl64(uint64_t v, unsigned k) {
    return (v << k) | (v >> (64 - k));
}

__device__ void keccak_f23(uint64_t s[25]) {
    uint64_t a[25];
#pragma unroll
    for (int i = 0; i < 25; i++) a[i] = s[i];

    for (int r = 1; r < 24; r++) { // skip round 0, matches main.go
        uint64_t c[5];
#pragma unroll
        for (int i = 0; i < 5; i++) c[i] = a[i] ^ a[i + 5] ^ a[i + 10] ^ a[i + 15] ^ a[i + 20];
        uint64_t d[5];
#pragma unroll
        for (int i = 0; i < 5; i++) d[i] = c[(i + 4) % 5] ^ rotl64(c[(i + 1) % 5], 1);
#pragma unroll
        for (int i = 0; i < 5; i++)
#pragma unroll
            for (int j = 0; j < 25; j += 5) a[i + j] ^= d[i];

        uint64_t b[25];
#pragma unroll
        for (int i = 0; i < 25; i++) b[i] = rotl64(a[PI[i]], RHO[i]);

#pragma unroll
        for (int j = 0; j < 5; j++)
#pragma unroll
            for (int i = 0; i < 5; i++)
                a[j * 5 + i] = b[j * 5 + i] ^ ((~b[j * 5 + (i + 1) % 5]) & b[j * 5 + (i + 2) % 5]);

        a[0] ^= RC[r];
    }

#pragma unroll
    for (int i = 0; i < 25; i++) s[i] = a[i];
}

__device__ __forceinline__ uint64_t load_le64(const uint8_t* p) {
    uint64_t v = 0;
#pragma unroll
    for (int i = 0; i < 8; i++) v |= (uint64_t)p[i] << (8 * i);
    return v;
}

__device__ __forceinline__ void store_le64(uint8_t* p, uint64_t v) {
#pragma unroll
    for (int i = 0; i < 8; i++) p[i] = (uint8_t)(v >> (8 * i));
}

constexpr int RATE = 136; // matches main.go

__device__ void deepseek_hash_v1(const uint8_t* data, int len, uint8_t out[32]) {
    uint64_t s[25];
#pragma unroll
    for (int i = 0; i < 25; i++) s[i] = 0;

    int off = 0;
    while (off + RATE <= len) {
        for (int i = 0; i < RATE / 8; i++) s[i] ^= load_le64(data + off + i * 8);
        keccak_f23(s);
        off += RATE;
    }

    uint8_t buf[RATE];
    for (int i = 0; i < RATE; i++) buf[i] = 0;
    int rem = len - off;
    for (int i = 0; i < rem; i++) buf[i] = data[off + i];
    buf[rem] = 0x06;
    buf[RATE - 1] |= 0x80;
    for (int i = 0; i < RATE / 8; i++) s[i] ^= load_le64(buf + i * 8);
    keccak_f23(s);

    for (int i = 0; i < 4; i++) store_le64(out + i * 8, s[i]);
}

// ---------------------------------------------------------------------------
// Search kernel
// ---------------------------------------------------------------------------

constexpr int MAX_INPUT_LEN = 192;

__global__ void search_kernel(const uint8_t* prefix, int prefix_len, const uint8_t* target,
                               int difficulty, unsigned long long* found) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = gridDim.x * blockDim.x;

    for (int nonce = idx; nonce < difficulty; nonce += stride) {
        if ((unsigned long long)nonce >= *found) continue; // already beaten, skip work

        uint8_t data[MAX_INPUT_LEN];
        int total = prefix_len;
        for (int i = 0; i < prefix_len; i++) data[i] = prefix[i];

        char digits[12];
        int dlen = 0;
        if (nonce == 0) {
            digits[dlen++] = '0';
        } else {
            int n = nonce;
            while (n > 0) {
                digits[dlen++] = (char)('0' + (n % 10));
                n /= 10;
            }
        }
        for (int i = dlen - 1; i >= 0; i--) data[total++] = (uint8_t)digits[i];

        uint8_t hash[32];
        deepseek_hash_v1(data, total, hash);

        bool match = true;
#pragma unroll
        for (int i = 0; i < 32; i++) {
            if (hash[i] != target[i]) { match = false; break; }
        }
        if (match) atomicMin(found, (unsigned long long)nonce);
    }
}

// ---------------------------------------------------------------------------
// Minimal flat JSON field extraction (schema is fixed/flat, no nested objects)
// ---------------------------------------------------------------------------

static bool json_find_key(const std::string& json, const std::string& key, size_t& value_pos) {
    std::string needle = "\"" + key + "\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return false;
    pos = json.find(':', pos + needle.size());
    if (pos == std::string::npos) return false;
    pos++;
    while (pos < json.size() && isspace((unsigned char)json[pos])) pos++;
    value_pos = pos;
    return true;
}

static bool json_get_string(const std::string& json, const std::string& key, std::string& out) {
    size_t pos;
    if (!json_find_key(json, key, pos)) return false;
    if (pos >= json.size() || json[pos] != '"') return false;
    pos++;
    size_t end = pos;
    while (end < json.size() && json[end] != '"') end++;
    out = json.substr(pos, end - pos);
    return true;
}

static bool json_get_int(const std::string& json, const std::string& key, long long& out) {
    size_t pos;
    if (!json_find_key(json, key, pos)) return false;
    size_t end = pos;
    while (end < json.size() && (isdigit((unsigned char)json[end]) || json[end] == '-')) end++;
    if (end == pos) return false;
    out = strtoll(json.substr(pos, end - pos).c_str(), nullptr, 10);
    return true;
}

static bool hex_decode32(const std::string& hex, uint8_t out[32]) {
    if (hex.size() != 64) return false;
    for (int i = 0; i < 32; i++) {
        auto hexval = [](char c) -> int {
            if (c >= '0' && c <= '9') return c - '0';
            if (c >= 'a' && c <= 'f') return c - 'a' + 10;
            if (c >= 'A' && c <= 'F') return c - 'A' + 10;
            return -1;
        };
        int hi = hexval(hex[i * 2]);
        int lo = hexval(hex[i * 2 + 1]);
        if (hi < 0 || lo < 0) return false;
        out[i] = (uint8_t)((hi << 4) | lo);
    }
    return true;
}

int main() {
    std::string input;
    {
        char chunk[4096];
        size_t n;
        while ((n = fread(chunk, 1, sizeof(chunk), stdin)) > 0) input.append(chunk, n);
    }

    std::string challenge_hex, salt;
    long long difficulty = 0, expire_at = 0;

    if (!json_get_string(input, "challenge", challenge_hex) ||
        !json_get_string(input, "salt", salt) ||
        !json_get_int(input, "difficulty", difficulty) ||
        !json_get_int(input, "expire_at", expire_at)) {
        fprintf(stderr, "json decode error: missing required field\n");
        return 1;
    }

    uint8_t target[32];
    if (!hex_decode32(challenge_hex, target)) {
        fprintf(stderr, "hex decode error: invalid challenge\n");
        return 1;
    }

    std::string prefix = salt + "_" + std::to_string(expire_at) + "_";
    if (prefix.size() + 11 > MAX_INPUT_LEN) {
        fprintf(stderr, "prefix too long for fixed input buffer\n");
        return 1;
    }
    if (difficulty <= 0 || difficulty > INT_MAX) {
        fprintf(stderr, "invalid difficulty\n");
        return 1;
    }

    uint8_t* d_prefix = nullptr;
    uint8_t* d_target = nullptr;
    unsigned long long* d_found = nullptr;

    CUDA_CHECK(cudaMalloc(&d_prefix, prefix.size()));
    CUDA_CHECK(cudaMalloc(&d_target, 32));
    CUDA_CHECK(cudaMalloc(&d_found, sizeof(unsigned long long)));

    CUDA_CHECK(cudaMemcpy(d_prefix, prefix.data(), prefix.size(), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_target, target, 32, cudaMemcpyHostToDevice));

    unsigned long long init_found = ULLONG_MAX;
    CUDA_CHECK(cudaMemcpy(d_found, &init_found, sizeof(init_found), cudaMemcpyHostToDevice));

    int block_size = 256;
    int grid_size = (int)((difficulty + block_size - 1) / block_size);
    if (grid_size < 1) grid_size = 1;
    if (grid_size > 65535) grid_size = 65535; // grid-stride loop covers the remainder

    search_kernel<<<grid_size, block_size>>>(d_prefix, (int)prefix.size(), d_target, (int)difficulty, d_found);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    unsigned long long result = 0;
    CUDA_CHECK(cudaMemcpy(&result, d_found, sizeof(result), cudaMemcpyDeviceToHost));

    cudaFree(d_prefix);
    cudaFree(d_target);
    cudaFree(d_found);

    if (result == ULLONG_MAX) {
        fprintf(stderr, "no solution found\n");
        return 1;
    }

    printf("%llu\n", result);
    return 0;
}
