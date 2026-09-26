const tok = process.env.DEEPSEEK_USER_TOKEN

async function createChatSession() {
    try {
        const url = "https://chat.deepseek.com/api/v0/chat_session/create";

        const response = await fetch(url, {
            method: "POST",
            headers: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36",
                "Authorization": "Bearer " + tok,
                "Content-Type": "application/json",
                "Accept": "application/json"
            },
            body: ""
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data.code !== 0) {
            throw new Error(`API Error: ${data.msg || 'Unknown error'} (Code: ${data.code})`);
        }
        
        let sessionId = data?.data?.biz_data?.chat_session?.id;
        if (!sessionId) {
            sessionId = data?.data?.biz_data?.id;
        }
        const ttl = data?.data?.biz_data?.ttl_seconds;
        
        if (sessionId) {
            return [sessionId, ttl]
        } else {
            throw new Error('No session ID in response');
        }
    } catch (error) {
        console.error('Error creating chat session:', error.message);
        throw error;
    }
}

async function getPoWChallenge(url = "/api/v0/chat/completion") {
    const response = await fetch('https://chat.deepseek.com/api/v0/chat/create_pow_challenge', {
        method: "POST",
        headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36",
            "Authorization": "Bearer " + tok,
            "Content-Type": "application/json",
            "Accept": "application/json"
        },
        body: '{"target_path":"' + url + '"}'
    });
    
    if (!response.ok) {
        throw new Error(`Challenge HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    
    if (data.code !== 0) {
        throw new Error(`Challenge API Error: ${data.msg || 'Unknown error'} (Code: ${data.code})`);
    }
    
    if (!data?.data?.biz_data?.challenge) {
        throw new Error('No challenge data received');
    }
    
    return data.data.biz_data.challenge;
}
async function getPoWSolution() {
    const challenge = await getPoWChallenge();
    const { execFileSync } = require('child_process');
    const path = require('path');

    // Pipe JSON via stdin directly to the solver — no shell involved, so there's
    // no dependency on cmd vs pwsh and no risk of shell-injection via challenge data.
    const output = execFileSync(path.resolve(__dirname, 'pow_solver.exe'), [], {
        input: JSON.stringify(challenge),
        encoding: 'utf-8',
        timeout: 60000
    });
    const lines = output.trim().split('\n');
    let nonce;
    for (let i = lines.length - 1; i >= 0; i--) {
        const line = lines[i].trim();
        if (/^\d+$/.test(line)) {
            nonce = line;
            break;
        }
    }
    if (!nonce) {
        const foundMatch = output.match(/Found nonce:\s*(\d+)/);
        if (foundMatch) {
            nonce = foundMatch[1];
        } else {
            throw new Error('Could not parse nonce from output');
        }
    }
    
    const powResponse = 
        {
            "algorithm": "DeepSeekHashV1",
            "challenge": challenge.challenge,
            "salt": challenge.salt,
            "answer": Number(nonce),
            "signature": challenge.signature,
            "target_path": challenge.target_path
        }
    return Buffer.from(JSON.stringify(powResponse)).toString('base64');
}
/**
 * Parse an open /chat/completion SSE stream (fetch Response) into Sable-style
 * events. Buffers partial lines across chunk boundaries and extracts the
 * assistant message_id for server-side chaining.
 */
async function* iterCompletionEvents(response) {
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let currentFragType = 'RESPONSE';
    
    while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });

        const lines = buffer.split('\n');
        buffer = lines.pop(); // keep the last (possibly partial) line for next chunk

        for (const line of lines) {
            if (!line.startsWith('data: ')) continue;
            const payload = line.slice(6);
            if (payload === '[DONE]') return;

            let obj;
            try {
                obj = JSON.parse(payload);
            } catch {
                continue;
            }

            const v = obj.v;
            const p = obj.p;
            const o = obj.o;

            if (v === undefined && p === undefined) continue;
            if (p === 'response' && o === 'BATCH') continue; // token usage / status only
            if (p === 'response/status' && o === 'SET') {
                if (v === 'FINISHED') yield { type: 'done' };
                continue;
            }
            if (typeof p === 'string' && p.includes('elapsed_secs')) continue;

            if (p === 'response/fragments' && o === 'APPEND') {
                if (Array.isArray(v) && v.length) {
                    const newType = v[0].type || 'RESPONSE';
                    currentFragType = newType;
                    const content = v[0].content || '';
                    if (content) {
                        yield { type: newType === 'THINK' ? 'thinking' : 'answer', text: content };
                    }
                }
                continue;
            }

            if (p === 'response/fragments/-1/content') {
                // Handle both o="APPEND" and o=undefined — DeepSeek sometimes sends
                // content continuation events without the APPEND operation tag.
                const text = typeof v === 'string' ? v : '';
                if (text) {
                    yield { type: currentFragType === 'THINK' ? 'thinking' : 'answer', text };
                }
                continue;
            }

            if (p === 'response/content' && o === 'APPEND') {
                // Token-by-token append shape distinct from response/fragments/-1/content.
                const text = typeof v === 'string' ? v : '';
                if (text) {
                    yield { type: currentFragType === 'THINK' ? 'thinking' : 'answer', text };
                }
                continue;
            }

            if (v && typeof v === 'object' && 'response' in v) {
                const respData = v.response;
                const fragments = respData.fragments || [];
                for (const frag of fragments) {
                    const ftype = frag.type || 'RESPONSE';
                    currentFragType = ftype;
                    const content = frag.content || '';
                    if (content) {
                        yield { type: ftype === 'THINK' ? 'thinking' : 'answer', text: content };
                    }
                }
                continue;
            }

            if (typeof v === 'string' && p === undefined) {
                yield { type: currentFragType === 'THINK' ? 'thinking' : 'answer', text: v };
                continue;
            }
        }
    }
}

async function chat(chatSessionId, prompt, pmid) {
    try {
        const powSolution = await getPoWSolution();
        
        const requestBody = {"chat_session_id":chatSessionId,"model_type":"default","prompt":prompt,"ref_file_ids":[],"thinking_enabled":false,"search_enabled":true,"action":null,"preempt":false, "parent_message_id": pmid}
        
        
        const response = await fetch('https://chat.deepseek.com/api/v0/chat/completion', {
            method: "POST",
            headers: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36",
                "Authorization": "Bearer " + tok,
                "Content-Type": "application/json",
                "Accept": "text/event-stream",
                "x-ds-pow-response": powSolution
            },
            body: JSON.stringify(requestBody)
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`HTTP error! status: ${response.status}, body: ${errorText}`);
        }

        let fullResponse = '';

        for await (const event of iterCompletionEvents(response)) {
            if (event.type === 'answer' || event.type === 'thinking') {
                fullResponse += event.text;
            } 
        }

        return fullResponse;
        
    } catch (error) {
        console.error('Error in chat:', error.message);
        throw error;
    }
}

module.exports = {
    createChatSession,
    chat,
    getPoWSolution,
    iterCompletionEvents
};