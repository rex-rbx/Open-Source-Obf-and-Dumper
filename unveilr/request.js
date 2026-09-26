const axios = require('axios');
const PROXY = {
  host: process.env.PROXY_HOST,
  port: Number(process.env.PROXY_PORT)
};
const DEFAULT_TIMEOUT = 30000;
const MAX_RETRIES = 3;
const RETRY_DELAY = 1000;
const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
const numset = '0123456789'.split('');
const random = (x = 0, y = 1) => Math.floor(Math.random() * (y - x + 1)) + x;
const generateId = (len, numbersOnly = false) => {
  const set = numbersOnly ? numset : charset;
  let r = '';
  for (let i = 0; i < len; i++) {
    r += set[random(0, set.length - 1)];
  }
  return r;
};
const request = async (url, options = {}) => {
  const {
    method = 'GET',
    headers = {},
    data = null,
    timeout = DEFAULT_TIMEOUT,
    proxy = PROXY,
    retries = MAX_RETRIES,
    retryOnProxyFail = true,
    responseType = 'text',
    validateStatus = null
  } = options;
  let lastError = null;
  let attempt = 0;
  while (attempt < retries) {
    attempt++;
    try {
      const config = {
        url: url,
        method: method,
        timeout: timeout,
        responseType: responseType,
        validateStatus: validateStatus || (status => status >= 200 && status < 300)
      };
      if (proxy) {
        config.proxy = proxy;
      }
      let finalHeaders = {
        ...headers
      };
      if (!url.match(/https:\/\/\w+\.roblox\.com/)) {
        finalHeaders = {
          ...finalHeaders,
          "traceparent": "00-".concat(generateId(49), "-00"),
          "Roblox-Id": generateId(16, true),
          "User-Agent": "Roblox/WinInet",
          "Krnl-Fingerprint": generateId(16),
          ...finalHeaders
        };
      }
      config.headers = finalHeaders;
      if (data) {
        config.data = data;
        if (!finalHeaders['Content-Type'] && typeof data === 'object') {
          config.headers['Content-Type'] = 'application/json';
        }
      }
      const response = await axios(config);
      return [true, response.data, response];
    } catch (err) {
      lastError = err;
      if (retryOnProxyFail && attempt < retries && isProxyError(err)) {
        console.warn("[Request] Proxy failed (attempt ".concat(attempt, "/").concat(retries, "), retrying without proxy..."));
        options.proxy = null;
        continue;
      }
      if (err.code === 'ECONNABORTED' && attempt < retries) {
        console.warn("[Request] Timeout (attempt ".concat(attempt, "/").concat(retries, "), retrying..."));
        await sleep(RETRY_DELAY * attempt);
        continue;
      }
      if (isNetworkError(err) && attempt < retries) {
        console.warn("[Request] Network error (attempt ".concat(attempt, "/").concat(retries, "), retrying..."));
        await sleep(RETRY_DELAY * attempt);
        continue;
      }
      break;
    }
  }
  return formatError(lastError);
};
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const isProxyError = err => {
  return err.code === 'ECONNREFUSED' || err.code === 'ECONNRESET' || err.code === 'ETIMEDOUT' || err.message?.includes('proxy') || err.message?.includes('tunnel');
};
const isNetworkError = err => {
  return err.code === 'ECONNREFUSED' || err.code === 'ECONNRESET' || err.code === 'ETIMEDOUT' || err.code === 'ENOTFOUND' || err.code === 'ECONNABORTED';
};
const formatError = err => {
  console.error("[Request] Error:", err.message);
  if (err.response) {
    return [false, "> Unable to fetch URL, message: ".concat(err.response.status, ": ").concat(err.response.statusText || "NO_STATUS_MESSAGE"), err.response];
  } else if (err.code === 'ECONNABORTED') {
    return [false, "> Unable to fetch URL, message: Request timed out.", null];
  } else if (err.code === 'ENOTFOUND') {
    return [false, "> Unable to fetch URL, message: Host not found.", null];
  } else if (err.code === 'ECONNREFUSED') {
    return [false, "> Unable to fetch URL, message: Connection refused.", null];
  } else {
    return [false, "> Unable to fetch URL, message: ".concat(err.message || "Unable to establish connection."), null];
  }
};
const get = (url, options = {}) => {
  return request(url, {
    ...options,
    method: 'GET'
  });
};
const post = (url, data, options = {}) => {
  return request(url, {
    ...options,
    method: 'POST',
    data
  });
};
const put = (url, data, options = {}) => {
  return request(url, {
    ...options,
    method: 'PUT',
    data
  });
};
const del = (url, options = {}) => {
  return request(url, {
    ...options,
    method: 'DELETE'
  });
};
const head = (url, options = {}) => {
  return request(url, {
    ...options,
    method: 'HEAD'
  });
};
const optionsMethod = (url, options = {}) => {
  return request(url, {
    ...options,
    method: 'OPTIONS'
  });
};
const patch = (url, data, options = {}) => {
  return request(url, {
    ...options,
    method: 'PATCH',
    data
  });
};
if (require.main === module) {
  const arg = process.argv[2];
  if (!arg) {
    console.error("Usage: node request.js <url>");
    process.exit(1);
  }
  (async () => {
    const [success, content, response] = await request(arg, {
      useRobloxHeaders: true,
      retries: 2
    });
    if (!success) {
      console.error(content);
      process.exit(1);
    }
    console.log(content);
  })();
}
module.exports = get