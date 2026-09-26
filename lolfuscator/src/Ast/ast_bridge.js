const http = require('http');
const fs = require('fs');
const path = require('path');
const lp = require('../Modules/luaparse.js');
let luamin = null;
function getLuamin() {
  if (!luamin) luamin = require('../Modules/luamin.js');
  return luamin;
}
var LUA_KEYWORDS = {
  'and': true,
  'break': true,
  'continue': true,
  'do': true,
  'else': true,
  'elseif': true,
  'end': true,
  'false': true,
  'for': true,
  'function': true,
  'if': true,
  'in': true,
  'local': true,
  'nil': true,
  'not': true,
  'or': true,
  'repeat': true,
  'return': true,
  'then': true,
  'true': true,
  'typeof': true,
  'until': true,
  'while': true
};
var FIRST_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_';
var NEXT_CHARS = FIRST_CHARS + '0123456789';
function shuffleArray(arr) {
  for (var i = arr.length - 1; i > 0; i--) {
    var j = Math.floor(Math.random() * (i + 1));
    var temp = arr[i];
    arr[i] = arr[j];
    arr[j] = temp;
  }
  return arr;
}
var shuffledFirst = FIRST_CHARS.split('');
var shuffledNext = NEXT_CHARS.split('');
var namePool = [];
var poolIdx = 0;
var curLen = 1;
function resetNameGenerator() {
  namePool = [];
  poolIdx = 0;
  curLen = 1;
  shuffleArray(shuffledFirst);
  shuffleArray(shuffledNext);
}
function fillPool(isUsed) {
  var total = Math.pow(63, curLen - 1);
  var allNames = [];
  for (var fi = 0; fi < 53; fi++) {
    for (var ri = 0; ri < total; ri++) {
      var rest = '';
      var n = ri;
      for (var d = 0; d < curLen - 1; d++) {
        rest = shuffledNext[n % 63] + rest;
        n = Math.floor(n / 63);
      }
      var name = shuffledFirst[fi] + rest;
      if (!isUsed(name)) {
        allNames.push(name);
      }
    }
  }
  shuffleArray(allNames);
  namePool = allNames;
  poolIdx = 0;
  curLen++;
}
function nextName(usedNames) {
  var isUsed = function (name) {
    return LUA_KEYWORDS[name] || usedNames[name];
  };
  while (poolIdx >= namePool.length) {
    fillPool(isUsed);
  }
  return namePool[poolIdx++];
}
function randomRenameLocals(ast) {
  var localNameSet = {};
  var allLocalNodes = [];
  function collect(node) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      for (var i = 0; i < node.length; i++) collect(node[i]);
      return;
    }
    if (node.type === 'Identifier' && node.isLocal) {
      localNameSet[node.name] = true;
      allLocalNodes.push(node);
    }
    for (var k in node) {
      if (k === 'globals' || k === 'comments') continue;
      collect(node[k]);
    }
  }
  collect(ast);
  var keepName = {};
  arr(ast.globals).forEach(function (g) {
    keepName[g.name] = true;
  });
  var reserved = {};
  arr(ast.globals).forEach(function (g) {
    reserved[g.name] = true;
  });
  Object.keys(localNameSet).forEach(function (n) {
    reserved[n] = true;
  });
  resetNameGenerator();
  var nameMap = {};
  Object.keys(localNameSet).forEach(function (originalName) {
    if (keepName[originalName]) {
      nameMap[originalName] = originalName;
      return;
    }
    var randomName = nextName(reserved);
    nameMap[originalName] = randomName;
    reserved[randomName] = true;
  });
  allLocalNodes.forEach(function (node) {
    if (nameMap[node.name]) {
      node.name = nameMap[node.name];
    }
  });
  for (var orig in nameMap) {
    var randomName = nameMap[orig];
    if (orig !== randomName && !ast.globals.some(function (g) {
      return g.name === randomName;
    })) {
      ast.globals.push({
        name: randomName
      });
    }
  }
}
function unmarkKeyIdentifiers(ast) {
  function walk(node) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      for (var i = 0; i < node.length; i++) walk(node[i]);
      return;
    }
    if (node.type === 'TableKeyString' && node.key && node.key.type === 'Identifier' && node.key.isLocal) {
      node.key.isLocal = false;
    }
    if (node.type === 'MemberExpression' && node.identifier && node.identifier.type === 'Identifier' && node.identifier.isLocal) {
      node.identifier.isLocal = false;
    }
    for (var k in node) {
      if (k === 'globals' || k === 'comments') continue;
      walk(node[k]);
    }
  }
  walk(ast);
}
function prepareAstForMinify(node, renameable) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) {
    for (var i = 0; i < node.length; i++) prepareAstForMinify(node[i], renameable);
    return;
  }
  if (node.type === 'TableConstructorExpression' && node.fields) {
    var fields = arr(node.fields);
    for (var i = 0; i < fields.length; i++) {
      var f = fields[i];
      if (f && f.type === 'TableKeyString' && f.key && f.key.type === 'Identifier') {
        if (f.key.name.indexOf('__') !== 0) {
          renameable.add(f.key.name);
        }
      }
    }
  }
  for (var k in node) {
    if (k === 'globals' || k === 'comments') continue;
    prepareAstForMinify(node[k], renameable);
  }
}
function markRenameableIdentifiers(node, renameable) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) {
    for (var i = 0; i < node.length; i++) markRenameableIdentifiers(node[i], renameable);
    return;
  }
  if (node.type === 'TableKeyString' && node.key && node.key.type === 'Identifier' && renameable.has(node.key.name)) {
    node.key.isLocal = true;
  }
  if (node.type === 'MemberExpression' && node.identifier && node.identifier.type === 'Identifier' && renameable.has(node.identifier.name)) {
    node.identifier.isLocal = true;
  }
  for (var k in node) {
    if (k === 'globals' || k === 'comments') continue;
    markRenameableIdentifiers(node[k], renameable);
  }
}
function optimizeForMinify(ast) {
  var renameable = new Set();
  prepareAstForMinify(ast, renameable);
  markRenameableIdentifiers(ast, renameable);
}
const EMPTY_ARR = [];
const RESERVED = new Set(['and', 'break', 'continue', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'typeof', 'until', 'while']);
function arr(x) {
  if (x == null) return EMPTY_ARR;
  return Array.isArray(x) ? x : Object.values(x);
}
function escStr(s) {
  return String(s == null ? '' : s).replace(/[\\"\n\r\0]/g, function (ch) {
    return ch === '\\' ? '\\\\' : ch === '"' ? '\\"' : ch === '\n' ? '\\n' : ch === '\r' ? '\\r' : '\\0';
  });
}
function fmtBinOp(op) {
  return op === 'and' || op === 'or' || op === '..' || op === '==' || op === '~=' || op === '<=' || op === '>=' ? op : op;
}
function fmtUnaryOp(op) {
  return op === 'not' ? 'not ' : op;
}
function fmtExprList(nodes, depth) {
  nodes = arr(nodes);
  if (nodes.length === 0) return '';
  var out = fmtExpr(nodes[0], depth);
  for (var i = 1; i < nodes.length; i++) out += ', ' + fmtExpr(nodes[i], depth);
  return out;
}
function fmtNameList(nodes) {
  nodes = arr(nodes);
  if (nodes.length === 0) return '';
  var out = nodes[0].name;
  for (var i = 1; i < nodes.length; i++) out += ', ' + nodes[i].name;
  return out;
}
function fmtFieldList(fields, depth) {
  fields = arr(fields);
  if (fields.length === 0) return '';
  var out = fmtField(fields[0], depth);
  for (var i = 1; i < fields.length; i++) out += ', ' + fmtField(fields[i], depth);
  return out;
}
function fmtExpr(e, depth) {
  if (!e || typeof e !== 'object') return 'nil';
  var t = e.type;
  var s = fmtExprInner(e, depth);
  if (e.inParens) s = '(' + s + ')';
  return s;
}
function fmtExprInner(e, depth) {
  if (!e || typeof e !== 'object') return 'nil';
  var t = e.type;
  switch (t) {
    case 'Identifier':
      return e.name;
    case 'NumericLiteral':
      return String(e.value != null ? e.value : e.raw);
    case 'StringLiteral':
      return '"' + escStr(e.value) + '"';
    case 'BooleanLiteral':
      return e.value ? 'true' : 'false';
    case 'NilLiteral':
      return 'nil';
    case 'VarargLiteral':
      return '...';
    case 'BinaryExpression':
      return fmtExpr(e.left, depth) + ' ' + fmtBinOp(e.operator) + ' ' + fmtExpr(e.right, depth);
    case 'LogicalExpression':
      return fmtExpr(e.left, depth) + ' ' + e.operator + ' ' + fmtExpr(e.right, depth);
    case 'UnaryExpression':
      return fmtUnaryOp(e.operator) + fmtExpr(e.argument, depth);
    case 'MemberExpression':
      return fmtExpr(e.base, depth) + (e.indexer === ':' ? ':' : '.') + fmtExpr(e.identifier, depth);
    case 'IndexExpression':
      return fmtExpr(e.base, depth) + '[' + fmtExpr(e.index, depth) + ']';
    case 'CallExpression':
      return fmtExpr(e.base, depth) + '(' + fmtExprList(e.arguments, depth) + ')';
    case 'MemberCallExpression':
      return fmtExpr(e.base, depth) + ':' + fmtExpr(e.method, depth) + '(' + fmtExprList(e.arguments, depth) + ')';
    case 'StringCallExpression':
      return fmtExpr(e.base, depth) + ' ' + fmtExpr(e.argument, depth);
    case 'TableConstructorExpression':
      return '{' + fmtFieldList(e.fields, depth) + '}';
    case 'FunctionDeclaration':
      return fmtFuncExpr(e, depth);
    default:
      return 'nil';
  }
}
function fmtField(f, depth) {
  var t = f.type;
  if (t === 'TableValue') return fmtExpr(f.value, depth);
  if (t === 'TableKeyString' || t === 'MapValue') return fmtExpr(f.key, depth) + ' = ' + fmtExpr(f.value, depth);
  if (t === 'TableKey') return '[' + fmtExpr(f.key, depth) + '] = ' + fmtExpr(f.value, depth);
  return fmtExpr(f.value, depth);
}
function fmtFuncExpr(e, depth) {
  var head = (e.inParens ? '(' : '') + (e.isLocal ? 'local ' : '') + 'function' + (e.identifier ? ' ' + fmtExpr(e.identifier, depth + 1) : '') + '(' + fmtExprList(e.parameters, depth + 1) + ')';
  var tail = '\n' + fmtBody(e.body, depth + 1) + '\n' + indent(depth) + 'end' + (e.inParens ? ')' : '');
  return head + tail;
}
function fmtStmt(s, depth) {
  if (!s || typeof s !== 'object') return '';
  var t = s.type;
  switch (t) {
    case 'LocalStatement':
      {
        var init = arr(s.init);
        return 'local ' + fmtNameList(s.variables) + (init.length > 0 ? ' = ' + fmtExprList(init, depth) : '');
      }
    case 'AssignmentStatement':
      return fmtExprList(s.variables, depth) + ' = ' + fmtExprList(s.init, depth);
    case 'CallStatement':
      return fmtExpr(s.expression, depth);
    case 'ReturnStatement':
      return 'return ' + fmtExprList(s.arguments, depth);
    case 'IfStatement':
      return fmtIf(s, depth);
    case 'WhileStatement':
      return 'while ' + fmtExpr(s.condition, depth) + ' do\n' + fmtBody(s.body, depth) + '\n' + indent(depth) + 'end';
    case 'RepeatStatement':
      return 'repeat\n' + fmtBody(s.body, depth) + '\n' + indent(depth) + 'until ' + fmtExpr(s.condition, depth);
    case 'NumericForStatement':
    case 'ForNumericStatement':
      return 'for ' + s.variable.name + ' = ' + fmtExpr(s.start, depth) + ', ' + fmtExpr(s['end'], depth) + (s.step ? ', ' + fmtExpr(s.step, depth) : '') + ' do\n' + fmtBody(s.body, depth) + '\n' + indent(depth) + 'end';
    case 'GenericForStatement':
    case 'ForGenericStatement':
      return 'for ' + fmtNameList(s.variables) + ' in ' + fmtExprList(s.iterators, depth) + ' do\n' + fmtBody(s.body, depth) + '\n' + indent(depth) + 'end';
    case 'DoStatement':
      return 'do\n' + fmtBody(s.body, depth) + '\n' + indent(depth) + 'end';
    case 'FunctionDeclaration':
      return fmtFuncExpr(s, depth);
    case 'BreakStatement':
      return 'break';
    case 'ContinueStatement':
      return 'continue';
    default:
      return '';
  }
}
function fmtIf(s, depth) {
  var clauses = arr(s.clauses);
  if (clauses.length === 0) return '';
  var out = '';
  for (var ci = 0; ci < clauses.length; ci++) {
    var cl = clauses[ci];
    if (cl.type === 'IfClause') {
      out += 'if ' + fmtExpr(cl.condition, depth) + ' then\n' + fmtBody(cl.body, depth);
    } else if (cl.type === 'ElseifClause') {
      out += '\n' + indent(depth) + 'elseif ' + fmtExpr(cl.condition, depth) + ' then\n' + fmtBody(cl.body, depth);
    } else if (cl.type === 'ElseClause') {
      out += '\n' + indent(depth) + 'else\n' + fmtBody(cl.body, depth);
    }
  }
  return out + '\n' + indent(depth) + 'end';
}
function indent(depth) {
  var s = '';
  for (var i = 0; i < depth; i++) s += '    ';
  return s;
}
function fmtBody(body, depth) {
  if (!body || body.length === 0) return '';
  var lines = [];
  var prefix = indent(depth + 1);
  for (var i = 0; i < body.length; i++) {
    var stmt = fmtStmt(body[i], depth + 1);
    if (!stmt) continue;
    var parts = stmt.split('\n');
    for (var j = 0; j < parts.length; j++) lines.push(prefix + parts[j]);
  }
  return lines.join('\n');
}
function processRequest(req) {
  if (req.mode === 'ping') {
    return {
      ok: true
    };
  } else if (req.mode === 'parse') {
    const ast = lp.parse(req.src, {
      scope: true,
      locations: req.locations === true,
      ranges: req.ranges === true,
      comments: true
    });
    return {
      ok: true,
      ast
    };
  } else if (req.mode === 'render') {
    const minify = req.minify !== false;
    let body;
    if (minify) {
      randomRenameLocals(req.ast);
      optimizeForMinify(req.ast);
      randomRenameLocals(req.ast);
      unmarkKeyIdentifiers(req.ast);
      body = getLuamin().minify(req.ast);
    } else {
      body = fmtBody(req.ast.body, 0);
    }
    const commentsArray = Array.isArray(req.ast.comments) ? req.ast.comments : Object.values(req.ast.comments || {});
    if (commentsArray.length > 0) {
      body = commentsArray.map(function (c) {
        return c.raw || '--' + (c.value || '');
      }).join('\n') + '\n' + body;
    }
    const [FirstLine, ...FollowingLines] = body.split('\n');
    body = FollowingLines.join('\n');
    return {
      ok: true,
      src: FirstLine + "\nreturn((function(...)" + body + "end)(...))"
    };
  }
  return {
    ok: false,
    err: 'unknown mode: ' + String(req.mode)
  };
}
function runStdio() {
  let chunks = [];
  process.stdin.on('data', c => chunks.push(c));
  process.stdin.on('end', () => {
    let exit = 0;
    let res;
    try {
      const req = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      res = processRequest(req);
      if (!res.ok) exit = 1;
    } catch (e) {
      res = {
        ok: false,
        err: String(e && e.stack || e)
      };
      exit = 1;
    }
    process.stdout.write(JSON.stringify(res));
    process.exit(exit);
  });
}
function runServer() {
  const pidFile = path.join(__dirname, '.server.pid');
  try {
    fs.writeFileSync(pidFile, String(process.pid));
  } catch {}
  const server = http.createServer((req, res) => {
    if (req.method !== 'POST') {
      res.writeHead(405, {
        'Content-Type': 'application/json'
      });
      res.end(JSON.stringify({
        ok: false,
        err: 'method not allowed'
      }));
      return;
    }
    let chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => {
      let out;
      try {
        const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        out = processRequest(body);
      } catch (e) {
        out = {
          ok: false,
          err: String(e && e.stack || e)
        };
      }
      res.writeHead(200, {
        'Content-Type': 'application/json'
      });
      res.end(JSON.stringify(out));
    });
  });
  server.listen(41337, '127.0.0.1');
}
if (process.argv.includes('--server')) {
  runServer();
} else {
  runStdio();
}