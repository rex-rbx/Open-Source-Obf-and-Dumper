import beautify from '../mods/beautifier.js';
import { is, print, Clear, fixString } from '../mods/helper.js';
import simpleAst from '../mods/simple-ast.js';
import query from '../mods/query.js';
const simple = new Set(["NumericLiteral", "NilLiteral", "StringLiteral", "CallExpression", "IndexExpression"]);
const isSimple = type => simple.has(type);
export default async (output, extraDos, funcIdentifiers, state) => {
  const encrypted = [];
  const encryptionKeys = {
    param_mul_45: null,
    param_mul_8: null,
    param_add_45: null,
    secret_key_8: null
  };
  let step = 0,
    stopE = false,
    stopC = false,
    decryptor;
  const firstFunc = body => {
    let step = 0;
    for (let stat of body) {
      if (stat.type == "WhileStatement") stat = stat.body.find(a => a.type);else if (stat.type == "IfStatement") stat = stat.clauses[0].body.find(a => a.type);
      if (step == 0 && stat.type == "AssignmentStatement" && is(stat.init, [{
        type: "BinaryExpression",
        left: {
          type: "BinaryExpression"
        },
        operator: "%"
      }])) {
        const expr = stat.init[0].left;
        if (expr.operator == "+") {
          encryptionKeys.param_add_45 = expr.right.raw;
          encryptionKeys.param_mul_45 = expr.left.right.raw;
          step++;
        }
      } else if (step == 1 && stat.type == "AssignmentStatement" && is(stat.init, [{
        type: "BinaryExpression",
        operator: "%",
        right: {
          type: "NumericLiteral",
          value: 257
        }
      }])) {
        const expr = stat.init[0].left;
        if (expr.operator == "*") {
          encryptionKeys.param_mul_8 = expr.right.raw;
          stopC = true;
          step++;
        }
      } else if (step == 1 && stat.type == "RepeatStatement") {
        encryptionKeys.param_mul_8 = stat.body.find(a => a.type).init[0].left.right.raw;
        stopC = true;
      }
    }
    return step;
  };
  if (extraDos.length) {
    const encryption = extraDos[extraDos.length - 2].body;
    for (let stat of encryption) {
      if (stat.type == "FunctionDeclaration") {
        if (is(stat, {
          isLocal: true,
          body: [{
            type: "IfStatement",
            clauses: [{
              type: "IfClause",
              condition: {
                type: "BinaryExpression"
              }
            }]
          }]
        })) {
          const body = stat.body[0].clauses[0].body;
          firstFunc(body);
        } else if (is(stat, {
          isLocal: false,
          body: [{
            type: "LocalStatement"
          }, {
            type: "IfStatement"
          }]
        })) {
          Clear(stat.body[stat.body.length - 1]);
          stat.body = stat.body.filter(a => a.type);
          if (isDecryptor(stat)) decryptor = stat.identifier;
        }
      }
    }
  }
  function isDecryptor(func) {
    if (encryptionKeys.secret_key_8) return;
    if (!func.parameters?.length) return;
    let IfStat = func.body[func.body.length - 1];
    if (IfStat.type == "ReturnStatement") IfStat = func.body[func.body.length - 2];
    let last = [];
    let sawDecryptShape = false;
    const isWeird = is(IfStat, {
      type: "IfStatement",
      clauses: [{}, {
        type: "ElseClause"
      }]
    });
    const elsebody = isWeird ? IfStat.clauses[1].body : func.body;
    if (isWeird) {
      for (const pre of func.body) {
        if (pre === IfStat) break;
        if (pre?.type == "AssignmentStatement" || pre?.type == "LocalStatement") last.push(pre);
      }
    }
    const hasIdentifier = (node, name) => {
      if (!node || typeof node != "object") return false;
      if (node.type == "Identifier" && node.name == name) return true;
      for (const key in node) {
        const value = node[key];
        if (Array.isArray(value)) {
          for (const child of value) {
            if (hasIdentifier(child, name)) return true;
          }
        } else if (value && typeof value == "object") {
          if (hasIdentifier(value, name)) return true;
        }
      }
      return false;
    };
    const evalNumeric = node => {
      if (!node) return null;
      if (node.type == "NumericLiteral") return Number(node.value ?? node.raw);
      if (node.type == "UnaryExpression" && node.operator == "-") {
        const n = evalNumeric(node.argument);
        return n == null ? null : -n;
      }
      if (node.type == "BinaryExpression") {
        const l = evalNumeric(node.left);
        const r = evalNumeric(node.right);
        if (l == null || r == null) return null;
        switch (node.operator) {
          case "+":
            return l + r;
          case "-":
            return l - r;
          case "*":
            return l * r;
          case "/":
            return r == 0 ? null : l / r;
          case "%":
            return r == 0 ? null : l % r;
          case "^":
            return Math.pow(l, r);
          default:
            return null;
        }
      }
      return null;
    };
    const resolveNumericInit = (name, visited = new Set()) => {
      if (!name || visited.has(name)) return null;
      visited.add(name);
      for (let i = last.length - 1; i >= 0; i--) {
        const stat = last[i];
        if (!(stat.type == "AssignmentStatement" || stat.type == "LocalStatement")) continue;
        const vars = stat.variables || [];
        const inits = stat.init || [];
        for (let vi = 0; vi < vars.length; vi++) {
          if (vars[vi]?.name != name) continue;
          const initNode = inits[vi] || inits[inits.length - 1];
          if (!initNode) return null;
          if (initNode.type == "Identifier") {
            return resolveNumericInit(initNode.name, visited);
          }
          const value = evalNumeric(initNode);
          if (value == null || !Number.isFinite(value)) return null;
          return String(Math.trunc(value));
        }
      }
      return null;
    };
    const hasStringByteCall = node => {
      if (!node || typeof node != "object") return false;
      if (node.type == "CallExpression") {
        const base = node.base;
        if (base?.type == "MemberExpression" && base.base?.name == "string" && base.identifier?.name == "byte" || base?.type == "IndexExpression" && base.base?.name == "string" && base.index?.name == "byte") return true;
      }
      for (const key in node) {
        const value = node[key];
        if (Array.isArray(value)) {
          for (const child of value) {
            if (hasStringByteCall(child)) return true;
          }
        } else if (value && typeof value == "object") {
          if (hasStringByteCall(value)) return true;
        }
      }
      return false;
    };
    const collectNumericLiterals = (node, out = []) => {
      if (!node || typeof node != "object") return out;
      if (node.type == "NumericLiteral") out.push(Number(node.value ?? node.raw));
      for (const key in node) {
        const value = node[key];
        if (Array.isArray(value)) {
          for (const child of value) collectNumericLiterals(child, out);
        } else if (value && typeof value == "object") {
          collectNumericLiterals(value, out);
        }
      }
      return out;
    };
    const findHardcodedSecret = node => {
      if (!node || typeof node != "object") return null;
      if (node.type == "BinaryExpression" && node.operator == "%") {
        let modValue = evalNumeric(node.right);
        if (modValue == null && node.right?.type == "Identifier") {
          const resolvedMod = resolveNumericInit(node.right.name);
          if (resolvedMod != null) modValue = Number(resolvedMod);
        }
        if (modValue == 256 && hasStringByteCall(node.left)) {
          const candidates = collectNumericLiterals(node.left).filter(n => Number.isFinite(n) && n >= 0 && n <= 255);
          if (candidates.length) return String(Math.trunc(candidates[candidates.length - 1]));
        }
      }
      for (const key in node) {
        const value = node[key];
        if (Array.isArray(value)) {
          for (const child of value) {
            const found = findHardcodedSecret(child);
            if (found != null) return found;
          }
        } else if (value && typeof value == "object") {
          const found = findHardcodedSecret(value);
          if (found != null) return found;
        }
      }
      return null;
    };
    for (let stat of elsebody) {
      if (!stat?.type) continue;
      const hardcoded = findHardcodedSecret(stat);
      if (hardcoded != null) {
        encryptionKeys.secret_key_8 = hardcoded;
        stopE = true;
        sawDecryptShape = true;
        break;
      }
      if (stat.type == "ForNumericStatement" || stat.type == "WhileStatement") {
        for (let i = 0; i < stat.body.length; i++) {
          const loopStat = stat.body[i];
          if (loopStat?.type != "AssignmentStatement") continue;
          const target = loopStat.variables?.[0];
          const init = loopStat.init?.[0];
          if (!target || target.type != "Identifier" || !init) continue;
          if (init.type != "BinaryExpression" || init.operator != "%") continue;
          let modValue = evalNumeric(init.right);
          if (modValue == null && init.right?.type == "Identifier") {
            const resolvedMod = resolveNumericInit(init.right.name);
            if (resolvedMod != null) modValue = Number(resolvedMod);
          }
          if (modValue != 256) continue;
          if (!hasIdentifier(init.left, target.name)) continue;
          sawDecryptShape = true;
          const resolved = resolveNumericInit(target.name);
          if (!resolved) continue;
          encryptionKeys.secret_key_8 = resolved;
          stopE = true;
          break;
        }
        if (stopE) break;
      }
      if (stat.type == "AssignmentStatement" || stat.type == "LocalStatement") last.push(stat);
    }
    return sawDecryptShape;
  }
  for (let func of query(output, "FunctionDeclaration")) {
    if (stopE && stopC) break;
    const ImportantFunc = func.body.find(a => is(a, {
      type: "IfStatement",
      clauses: [{
        type: "IfClause",
        condition: {
          type: "BinaryExpression"
        }
      }]
    }));
    if (ImportantFunc && step != 2) {
      const body = ImportantFunc.clauses[0].body;
      step = firstFunc(body);
      if (step == 2) Clear(func);
    } else {
      const isDecrypt = isDecryptor(func);
      if (!isDecrypt) continue;
      decryptor = func.identifier;
      Clear(func);
    }
  }
  let code = [];
  if (encryptionKeys.param_add_45 && !encryptionKeys.secret_key_8) {
    for (let func of query(output, {
      type: "CallExpression",
      base: {
        type: "FunctionDeclaration"
      }
    })) {
      if (isDecryptor(func.base)) {
        print("decryptor is inlined");
        decryptor = func.base;
        break;
      }
    }
  }
  print("Encryption Keys:", encryptionKeys);
  const tryFindKeyInRoot = (root, name) => {
    if (!root) return null;
    try {
      for (const stat of query(root, "AssignmentStatement")) {
        const vars = stat.variables || [];
        const inits = stat.init || [];
        for (let i = 0; i < vars.length; i++) {
          const variable = vars[i];
          const initNode = inits[i] || inits[inits.length - 1];
          if (!variable || variable.type !== "Identifier") continue;
          if (variable.name !== name) continue;
          if (initNode && initNode.type === "NumericLiteral") return Number(initNode.value ?? initNode.raw);
        }
      }
      for (const stat of query(root, "LocalStatement")) {
        const vars = stat.variables || [];
        const inits = stat.init || [];
        for (let i = 0; i < vars.length; i++) {
          const variable = vars[i];
          const initNode = inits[i] || inits[inits.length - 1];
          if (!variable || variable.type !== "Identifier") continue;
          if (variable.name !== name) continue;
          if (initNode && initNode.type === "NumericLiteral") return Number(initNode.value ?? initNode.raw);
        }
      }
    } catch (e) {}
    return null;
  };
  const astSources = [];
  if (Array.isArray(output)) astSources.push(output);
  if (Array.isArray(extraDos)) for (const e of extraDos) astSources.push(e);
  for (const k of Object.keys(encryptionKeys)) {
    if (!encryptionKeys[k]) {
      for (const src of astSources) {
        const found = tryFindKeyInRoot(src, k);
        if (found != null) {
          encryptionKeys[k] = found;
          break;
        }
      }
    }
  }
  if (!encryptionKeys.param_mul_45) throw new Error("Encrypt strings is off");
  for (let key in encryptionKeys) {
    if (!encryptionKeys[key]) throw new Error("UNABLE TO FIND DECRYPTION KEY ".concat(key));
    print("FOUND DECRYPTION KEY", key, encryptionKeys[key]);
    code.push("".concat(key, " = ").concat(encryptionKeys[key], ";"));
  }
  if (!decryptor) return console.error("UNABLE TO FIND DECRYPTOR!!");
  const solveNumeric = node => {
    if (!node) return null;
    if (node.type == "NumericLiteral") return Number(node.value ?? node.raw);
    if (node.type == "UnaryExpression" && node.operator == "-") {
      const n = solveNumeric(node.argument);
      return n == null ? null : -n;
    }
    if (node.type == "BinaryExpression") {
      const l = solveNumeric(node.left);
      const r = solveNumeric(node.right);
      if (l == null || r == null) return null;
      switch (node.operator) {
        case "+":
          return l + r;
        case "-":
          return l - r;
        case "*":
          return l * r;
        case "/":
          return r == 0 ? null : l / r;
        case "%":
          return r == 0 ? null : l % r;
        case "^":
          return Math.pow(l, r);
        default:
          return null;
      }
    }
    return null;
  };
  const copyLiteral = node => {
    if (!node) return null;
    if (node.type == "StringLiteral") {
      const value = node.value ?? "";
      return {
        type: "StringLiteral",
        value,
        raw: node.raw ?? "\"".concat(fixString(value, '"', false), "\"")
      };
    }
    if (node.type == "NumericLiteral") {
      const value = Number(node.value ?? node.raw);
      if (!Number.isFinite(value)) return null;
      return {
        type: "NumericLiteral",
        value,
        raw: node.raw ?? String(value)
      };
    }
    return null;
  };
  const rewriteCallsWithKnownTableSlots = (stat, slots, scalars) => {
    const resolveSlot = (node, expectedType) => {
      if (!node) return null;
      if (node.type == expectedType) return copyLiteral(node);
      if (node.type == "Identifier") {
        const lit = scalars.get(node.name);
        if (lit && lit.type == expectedType) return copyLiteral(lit);
      }
      if (expectedType == "NumericLiteral") {
        const n = solveNumeric(node);
        if (n != null && Number.isFinite(n)) return {
          type: "NumericLiteral",
          value: n,
          raw: String(Math.trunc(n))
        };
        if (node.type == "Identifier") {
          const lit = scalars.get(node.name);
          if (lit?.type == "NumericLiteral") return copyLiteral(lit);
        }
      }
      if (node.type != "IndexExpression" || node.base?.type != "Identifier") return null;
      const idx = solveNumeric(node.index);
      if (idx == null) return null;
      const lit = slots.get("".concat(node.base.name, ":").concat(idx));
      if (!lit || lit.type != expectedType) return null;
      return copyLiteral(lit);
    };
    const walk = node => {
      if (!node || typeof node != "object") return;
      if (node.type == "CallExpression" && Array.isArray(node.arguments) && node.arguments.length >= 2) {
        const enc = resolveSlot(node.arguments[0], "StringLiteral");
        const seed = resolveSlot(node.arguments[1], "NumericLiteral");
        if (enc) node.arguments[0] = enc;
        if (seed) node.arguments[1] = seed;
      }
      for (const key in node) {
        const value = node[key];
        if (Array.isArray(value)) {
          for (const child of value) walk(child);
        } else if (value && typeof value == "object") {
          walk(value);
        }
      }
    };
    walk(stat);
  };
  const applySlotAssignments = (stat, slots, scalars) => {
    if (!(stat.type == "AssignmentStatement" || stat.type == "LocalStatement")) return;
    const vars = stat.variables || [];
    const inits = stat.init || [];
    for (let i = 0; i < vars.length; i++) {
      const variable = vars[i];
      if (variable?.type != "IndexExpression" || variable.base?.type != "Identifier") continue;
      const idx = solveNumeric(variable.index);
      if (idx == null) continue;
      const key = "".concat(variable.base.name, ":").concat(idx);
      const initNode = inits[i] || inits[inits.length - 1];
      if (!initNode) {
        slots.delete(key);
        continue;
      }
      let lit = copyLiteral(initNode);
      if (!lit && initNode.type == "Identifier") {
        const fromScalar = scalars.get(initNode.name);
        if (fromScalar) lit = copyLiteral(fromScalar);
      }
      if (!lit && initNode.type == "IndexExpression" && initNode.base?.type == "Identifier") {
        const fromIdx = solveNumeric(initNode.index);
        if (fromIdx != null) {
          const fromSlot = slots.get("".concat(initNode.base.name, ":").concat(fromIdx));
          if (fromSlot) lit = copyLiteral(fromSlot);
        }
      }
      if (!lit) {
        const n = solveNumeric(initNode);
        if (n != null && Number.isFinite(n)) {
          lit = {
            type: "NumericLiteral",
            value: n,
            raw: String(Math.trunc(n))
          };
        }
      }
      if (lit && (lit.type == "StringLiteral" || lit.type == "NumericLiteral")) slots.set(key, lit);else slots.delete(key);
    }
  };
  const applyScalarAssignments = (stat, scalars, slots) => {
    if (!(stat.type == "AssignmentStatement" || stat.type == "LocalStatement")) return;
    const vars = stat.variables || [];
    const inits = stat.init || [];
    for (let i = 0; i < vars.length; i++) {
      const variable = vars[i];
      if (variable?.type != "Identifier") continue;
      const initNode = inits[i] || inits[inits.length - 1];
      if (!initNode) {
        scalars.delete(variable.name);
        continue;
      }
      let lit = copyLiteral(initNode);
      if (!lit && initNode.type == "Identifier") {
        const fromScalar = scalars.get(initNode.name);
        if (fromScalar) lit = copyLiteral(fromScalar);
      }
      if (!lit && initNode.type == "IndexExpression" && initNode.base?.type == "Identifier") {
        const fromIdx = solveNumeric(initNode.index);
        if (fromIdx != null) {
          const fromSlot = slots.get("".concat(initNode.base.name, ":").concat(fromIdx));
          if (fromSlot) lit = copyLiteral(fromSlot);
        }
      }
      if (lit && (lit.type == "StringLiteral" || lit.type == "NumericLiteral")) {
        scalars.set(variable.name, lit);
        continue;
      }
      const n = solveNumeric(initNode);
      if (n != null && Number.isFinite(n)) {
        scalars.set(variable.name, {
          type: "NumericLiteral",
          value: n,
          raw: String(Math.trunc(n))
        });
      } else {
        scalars.delete(variable.name);
      }
    }
  };
  const processBlock = (body, inheritedSlots = new Map(), inheritedScalars = new Map()) => {
    const slots = new Map(inheritedSlots);
    const scalars = new Map(inheritedScalars);
    for (const stat of body || []) {
      if (!stat?.type) continue;
      rewriteCallsWithKnownTableSlots(stat, slots, scalars);
      applySlotAssignments(stat, slots, scalars);
      applyScalarAssignments(stat, scalars, slots);
      if (stat.type == "IfStatement") {
        for (const clause of stat.clauses || []) processBlock(clause.body, slots, scalars);
      } else if (stat.type == "WhileStatement" || stat.type == "RepeatStatement" || stat.type == "DoStatement" || stat.type == "ForNumericStatement" || stat.type == "ForGenericStatement" || stat.type == "FunctionDeclaration") {
        processBlock(stat.body, slots, scalars);
      }
    }
    return slots;
  };
  processBlock(output);
  const collectEncrypted = () => {
    const localEncrypted = [];
    const literalByTableIndex = new Map();
    for (const stat of query(output, "AssignmentStatement")) {
      const vars = stat.variables || [];
      const inits = stat.init || [];
      for (let i = 0; i < vars.length; i++) {
        const variable = vars[i];
        if (variable?.type != "IndexExpression" || variable.base?.type != "Identifier") continue;
        const idx = solveNumeric(variable.index);
        if (idx == null) continue;
        const initNode = inits[i] || inits[inits.length - 1];
        if (!initNode || initNode.type != "StringLiteral" && initNode.type != "NumericLiteral") continue;
        literalByTableIndex.set("".concat(variable.base.name, ":").concat(idx), initNode);
      }
    }
    const resolveLiteralArg = (arg, expectedType) => {
      if (!arg) return null;
      if (arg.type == expectedType) return copyLiteral(arg);
      if (arg.type == "IndexExpression" && arg.base?.type == "Identifier") {
        const idx = solveNumeric(arg.index);
        if (idx == null) return null;
        const lit = literalByTableIndex.get("".concat(arg.base.name, ":").concat(idx));
        if (!lit || lit.type != expectedType) return null;
        return copyLiteral(lit);
      }
      if (expectedType == "NumericLiteral") {
        const n = solveNumeric(arg);
        if (n == null || !Number.isFinite(n)) return null;
        return {
          type: "NumericLiteral",
          value: n,
          raw: String(Math.trunc(n))
        };
      }
      return null;
    };
    const seenEncrypted = new Set();
    const pushEncrypted = node => {
      if (!node) return;
      if (seenEncrypted.has(node)) return;
      let call;
      if (node.type == "IndexExpression" && node.index?.type == "CallExpression") call = node.index;else if (node.type == "CallExpression") call = node;
      if (!call || !Array.isArray(call.arguments) || call.arguments.length < 2) return;
      const enc = resolveLiteralArg(call.arguments[0], "StringLiteral");
      const seed = resolveLiteralArg(call.arguments[1], "NumericLiteral");
      if (!enc || !seed) return;
      seenEncrypted.add(node);
      localEncrypted.push({
        node,
        enc,
        seed
      });
    };
    for (const call of query(output, {
      type: "CallExpression",
      arguments: [{
        type: "StringLiteral"
      }, {}]
    })) pushEncrypted(call);
    for (const idx of query(output, {
      type: "IndexExpression",
      index: {
        type: "CallExpression",
        arguments: [{
          type: "StringLiteral"
        }, {}]
      }
    })) pushEncrypted(idx);
    return localEncrypted;
  };
  const codePreamble = code.join("\n");
  const fromBytes = bytes => {
    let out = "";
    for (const byte of bytes) out += String.fromCharCode((Number(byte) || 0) & 0xff);
    return out;
  };
  const fromHex = hex => {
    if (typeof hex != "string" || hex.length % 2 != 0) return "";
    let out = "";
    for (let i = 0; i < hex.length; i += 2) {
      const byte = Number.parseInt(hex.substring(i, i + 2), 16);
      if (!Number.isFinite(byte)) return "";
      out += String.fromCharCode(byte & 0xff);
    }
    return out;
  };
  const runBatch = async batch => {
    const Table = simpleAst.emptyTable();
    for (const x of batch) {
      Table.fields.push({
        type: "TableValue",
        value: simpleAst.fieldsTable([x.enc, x.seed])
      });
    }
    const StringsDef = {
      type: "AssignmentStatement",
      variables: [{
        type: "Identifier",
        name: "strings"
      }],
      init: [Table]
    };
    let codeStr = codePreamble + "\n" + beautify([StringsDef]) + "\ndo\n\tlocal floor = math.floor\n\tlocal random = math.random;\n\tlocal remove = table.remove;\n\tlocal char = string.char;\n\tlocal state_45 = 0\n\tlocal state_8 = 2\n\tlocal digits = {}\n\tlocal charmap = {};\n\tlocal i = 0;\n\n\tlocal nums = {};\n\tfor i = 1, 256 do\n\t\tnums[i] = i;\n\tend\n\n\trepeat\n\t\tlocal idx = random(1, #nums);\n\t\tlocal n = remove(nums, idx);\n\t\tcharmap[n] = char(n - 1);\n\tuntil #nums == 0;\n\n\tlocal prev_values = {}\n\tlocal function get_next_pseudo_random_byte()\n\t\tif #prev_values == 0 then\n\t\t\tstate_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832\n\t\t\trepeat\n\t\t\t\tstate_8 = state_8 * param_mul_8 % 257\n\t\t\tuntil state_8 ~= 1\n\t\t\tlocal r = state_8 % 32\n\t\t\tlocal n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r\n\t\t\tlocal rnd = floor(n % 1 * 2 ^ 32) + floor(n)\n\t\t\tlocal low_16 = rnd % 65536\n\t\t\tlocal high_16 = (rnd - low_16) / 65536\n\t\t\tlocal b1 = low_16 % 256\n\t\t\tlocal b2 = (low_16 - b1) / 256\n\t\t\tlocal b3 = high_16 % 256\n\t\t\tlocal b4 = (high_16 - b3) / 256\n\t\t\tprev_values = { b1, b2, b3, b4 }\n\t\tend\n\t\treturn table.remove(prev_values)\n\tend\n\n\tlocal realStrings = {};\n\tlocal STRINGS = setmetatable({}, {\n\t\t__index = realStrings;\n\t\t__metatable = nil;\n\t});\n  \tlocal function DECRYPT(str, seed)\n\t\tlocal realStringsLocal = realStrings;\n\t\tif(realStringsLocal[seed]) then else\n\t\t\tprev_values = {};\n\t\t\tlocal chars = charmap;\n\t\t\tstate_45 = seed % 35184372088832\n\t\t\tstate_8 = seed % 255 + 2\n\t\t\tlocal len = string.len(str);\n\t\t\trealStringsLocal[seed] = \"\";\n\t\t\tlocal prevVal = secret_key_8;\n\t\t\tfor i=1, len do\n\t\t\t\tprevVal = (string.byte(str, i) + get_next_pseudo_random_byte() + prevVal) % 256\n\t\t\t\trealStringsLocal[seed] = realStringsLocal[seed] .. chars[prevVal + 1];\n\t\t\tend\n\t\tend\n\t\treturn seed;\n\tend\n    local function DECRYPT_PACKED(idx)\n        local v = strings[idx]\n        if not v then\n            return 0\n        end\n\n        local value = STRINGS[DECRYPT(v[1], v[2])]\n        return #value, string.byte(value, 1, #value)\n    end\n\n    return DECRYPT_PACKED\nend";
    const Loader = state.loadstring(codeStr);
    if (typeof Loader == "string") throw new Error(Loader);
    const DecryptPacked = (await Loader())[0];
    if (typeof DecryptPacked != "function") throw new Error("UNABLE TO LOAD DECRYPTOR FUNCTION");
    let replaced = 0;
    for (let i = 0; i < batch.length; i++) {
      const encoded = batch[i].node;
      const packed = await DecryptPacked(i + 1);
      if (!Array.isArray(packed)) continue;
      const length = Number(packed[0]) || 0;
      const val = fromBytes(packed.slice(1, 1 + length));
      Clear(encoded);
      encoded.type = "StringLiteral";
      encoded.value = val;
      encoded.raw = "\"".concat(fixString(val, '"', false), "\"");
      replaced++;
    }
    return replaced;
  };
  let totalReplaced = 0;
  let hadAnyCandidates = false;
  for (let pass = 0; pass < 6; pass++) {
    const batch = collectEncrypted();
    if (!batch.length) break;
    hadAnyCandidates = true;
    const replaced = await runBatch(batch);
    totalReplaced += replaced;
    if (replaced == 0) break;
  }
  if (!hadAnyCandidates) {
    print("No encrypted strings found");
    return output;
  }
  const unresolved = [];
  for (const idx of query(output, {
    type: "IndexExpression",
    index: {
      type: "CallExpression",
      arguments: [{}, {}]
    }
  })) {
    if (idx.base?.type != "Identifier") continue;
    if (idx.index.base?.type != "Identifier") continue;
    const expr = beautify(idx, {
      expr: true
    });
    if (typeof expr != "string" || !expr.length) continue;
    unresolved.push({
      node: idx,
      expr
    });
  }
  if (unresolved.length) {
    try {
      const bodyNoTailReturn = output.filter((stat, i) => !(i == output.length - 1 && stat?.type == "ReturnStatement"));
      const evalLines = [];
      for (let i = 0; i < unresolved.length; i++) {
        evalLines.push("do\n\tlocal __ok, __val = pcall(function() return ".concat(unresolved[i].expr, " end)\n\tif __ok and type(__val) == \"string\" then\n\t\t__results[").concat(i + 1, "] = __pack_hex(__val)\n\telse\n\t\t__results[").concat(i + 1, "] = false\n\tend\nend"));
      }
      const runtimeCode = "\nlocal __dummy\n__dummy = setmetatable({}, {\n\t__index = function() return __dummy end,\n\t__newindex = function() end,\n\t__call = function() return __dummy end,\n\t__tostring = function() return \"\" end,\n\t__len = function() return 0 end,\n\t__concat = function(a, b) return tostring(a) .. tostring(b) end,\n\t__add = function() return 0 end,\n\t__sub = function() return 0 end,\n\t__mul = function() return 0 end,\n\t__div = function() return 0 end,\n\t__mod = function() return 0 end,\n\t__pow = function() return 0 end,\n\t__eq = function() return false end,\n\t__lt = function() return false end,\n\t__le = function() return false end,\n})\n\nlocal __base = {\n\tmath = math,\n\tstring = string,\n\ttable = table,\n\tipairs = ipairs,\n\tpairs = pairs,\n\tnext = next,\n\tpcall = pcall,\n\txpcall = xpcall,\n\ttype = type,\n\ttonumber = tonumber,\n\ttostring = tostring,\n\tselect = select,\n\tsetmetatable = setmetatable,\n\tgetmetatable = getmetatable,\n\tunpack = unpack or table.unpack,\n\terror = function() return nil end,\n\tprint = function() end,\n\twarn = function() end,\n}\n\nlocal __env = setmetatable({}, {\n\t__index = function(_, k)\n\t\tlocal v = __base[k]\n\t\tif v ~= nil then return v end\n\t\treturn __dummy\n\tend,\n\t__newindex = function(t, k, v)\n\t\trawset(t, k, v)\n\tend,\n})\n\nsetfenv(1, __env)\n" + beautify(bodyNoTailReturn) + "\nlocal function __pack_hex(value)\n\tlocal out = table.create(#value)\n\tfor i = 1, #value do\n\t\tout[i] = string.format(\"%02x\", string.byte(value, i))\n\tend\n\treturn table.concat(out)\nend\n\nlocal __results = {}\n" + evalLines.join("\n") + "\nreturn table.unpack(__results)\n";
      const RuntimeLoader = state.loadstring(runtimeCode);
      if (typeof RuntimeLoader != "string") {
        const runtimeResults = await RuntimeLoader();
        for (let i = 0; i < unresolved.length; i++) {
          const packedHex = runtimeResults?.[i];
          if (typeof packedHex != "string") continue;
          const value = fromHex(packedHex);
          if (!value.length && packedHex.length) continue;
          Clear(unresolved[i].node);
          unresolved[i].node.type = "StringLiteral";
          unresolved[i].node.value = value;
          unresolved[i].node.raw = "\"".concat(fixString(value, '"', false), "\"");
        }
      }
    } catch (err) {
      console.error("runtime-assisted decrypt fallback failed", err);
    }
  }
  print("Decrypted strings:", totalReplaced);
  return output;
};