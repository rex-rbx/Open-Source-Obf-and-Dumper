# AST Bridge Server

The `ast_bridge.js` has two modes: **stdio** (default) and **server**.

## Auto Mode (Recommended)

The `Parser` module automatically starts the server on first use. No manual setup needed.

## Persistent Server (Faster Repeated Runs)

Start the server once in the background so all subsequent runs skip Node.js cold start (~500ms):

```bash
node src/Ast/ast_bridge.js --server &
```

The `Parser` module detects an existing server on `127.0.0.1:41337` and reuses it instead of spawning a new one.

To stop: kill the node process on port 41337.

## API

Send POST requests with JSON bodies to `http://127.0.0.1:41337`:

### Ping
```json
{"mode": "ping"}
```

### Parse
```json
{"mode": "parse", "src": "print('hello')"}
```

### Render
```json
{"mode": "render", "ast": <ast>, "minify": true}
```
