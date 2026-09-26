const beautify = require("../mods/beautifier");
const {
  search,
  searchOr,
  searchIs,
  is,
  print,
  Clear
} = require("../mods/helper");
const {
  spawn
} = require("child_process");
const simpleAst = require("../mods/simple-ast");
const fs = require("fs").promises;
module.exports = async (output, extraDos, funcIdentifiers, state) => {
  const encryptionKeys = {
    param_mul_45: null,
    param_mul_8: null,
    param_add_45: null,
    secret_key_8: null
  };
  let step = 0,
    stopE = false,
    decryptor,
    stringsTable;
  const firstFunc = body => {
    let step = 0;
    for (let stat of body) {
      const isWhile = stat.type == "WhileStatement";
      if (isWhile) stat = stat.body.find(a => a.type);
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
          step++;
        }
      } else if (step == 1 && stat.type == "RepeatStatement") {
        encryptionKeys.param_mul_8 = stat.body[0].init[0].left.right.raw;
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
    let IfStat = func.body[func.body.length - 1];
    if (IfStat.type == "ReturnStatement") IfStat = func.body[func.body.length - 2];
    const elsebody = is(IfStat, {
      type: "IfStatement",
      clauses: [{}, {
        type: "ElseClause"
      }]
    }) ? IfStat.clauses[1].body : func.body;
    let last = [];
    for (let stat of elsebody) {
      if (stat.type == "ForNumericStatement" || stat.type == "WhileStatement") {
        print("ofc");
        let ident;
        for (let i = 0; i < stat.body.length; i++) {
          if (is(stat.body[i], {
            type: "AssignmentStatement",
            init: [{
              type: "BinaryExpression"
            }]
          })) {
            const init = stat.body[i].init[0];
            const secretKey = init.operator == "%" ? init.left.right.name : init.right;
            if (secretKey.type == "NumericLiteral") {
              encryptionKeys.secret_key_8 = secretKey.value;
              stopE = true;
              break;
            }
            for (let i = last.length - 1; i > 0; i--) {
              if (last[i].variables[0].name == secretKey) {
                encryptionKeys.secret_key_8 = last[i].init[0].raw;
                stopE = true;
                break;
              }
            }
            break;
          }
        }
      }
      if (stat.type == "AssignmentStatement" || stat.type == "LocalStatement") last.push(stat);
    }
    return true;
  }
  for (let stat of searchOr(output, "AssignmentStatement", "LocalStatement")) {
    if (stopE) break;
    for (let func of stat.init) {
      if (func?.type != "FunctionDeclaration") continue;
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
      } else {
        const isDecrypt = isDecryptor(func);
        if (!isDecrypt) continue;
        decryptor = stat.variables[0];
      }
    }
  }
  let code = [],
    encrypted = [];
  if (encryptionKeys.param_add_45 && !encryptionKeys.secret_key_8) {
    for (let func of searchIs(output, {
      type: "CallExpression",
      base: {
        type: "FunctionDeclaration"
      }
    })) {
      if (isDecryptor(func.base)) {
        print("decryptor is inlined");
        encrypted.push(func);
        decryptor = func.base;
        break;
      }
    }
  }
  print("Encryption Keys:", encryptionKeys);
  if (!encryptionKeys.param_mul_45) throw new Error("Encrypt strings is off");
  for (let key in encryptionKeys) {
    if (!encryptionKeys[key]) throw new Error("UNABLE TO FIND DECRYPTION KEY ".concat(key));
    print("FOUND DECRYPTION KEY", key, encryptionKeys[key]);
    code.push("".concat(key, " = ").concat(encryptionKeys[key], ";"));
  }
  if (!decryptor) return console.error("UNABLE TO FIND DECRYPTOR!!");
  const decryptors = [decryptor];
  const isDecryptor2 = x => decryptors.find(a => is(a, x));
  if (decryptor.type == "Identifier") for (let ass of searchIs(output, {
    type: "AssignmentStatement",
    variables: [{
      type: "Identifier"
    }],
    init: [decryptor]
  })) {
    decryptors.push(ass.variables[0]);
  }
  for (let idx of search(output, "IndexExpression")) {
    const call = idx.index;
    if (is(call, {
      type: "CallExpression",
      arguments: [{
        type: "StringLiteral"
      }, {
        type: "NumericLiteral"
      }]
    })) {
      if (isDecryptor2(call.base)) {
        stringsTable = idx.base;
        break;
      }
    }
  }
  for (let call of searchIs(output, {
    type: "CallExpression",
    arguments: [{
      type: "StringLiteral"
    }, {
      type: "NumericLiteral"
    }]
  })) encrypted.push(call);
  for (let idx of searchIs(output, {
    type: "IndexExpression",
    base: {},
    index: {
      type: "CallExpression",
      base: {
        type: "IndexExpression",
        base: funcIdentifiers.regtable
      },
      arguments: [{
        type: "StringLiteral"
      }, {
        type: "NumericLiteral"
      }]
    }
  })) {
    const call = idx.index;
    const base = call.base;
    if (base.index.type == "IndexExpression" && base.index.base.name == funcIdentifiers.upvalues && base.index.index.type == "NumericLiteral" || base.index.type == "Identifier") {
      idx.base = stringsTable;
      encrypted.push(call);
    }
  }
  if (!encrypted.length) return console.error("ENCRYPTED STRINGS LIST IS EMPTY");
  const Table = simpleAst.emptyTable();
  for (let x of encrypted) {
    const [enc, seed] = x.arguments;
    Table.fields.push({
      type: "TableValue",
      value: simpleAst.fieldsTable([enc, seed])
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
  code.push(beautify([StringsDef]));
  let codeStr = code.join("\n") + "\ndo\n\tlocal floor = math.floor\n\tlocal random = math.random;\n\tlocal remove = table.remove;\n\tlocal char = string.char;\n\tlocal state_45 = 0\n\tlocal state_8 = 2\n\tlocal digits = {}\n\tlocal charmap = {};\n\tlocal i = 0;\n\n\tlocal nums = {};\n\tfor i = 1, 256 do\n\t\tnums[i] = i;\n\tend\n\n\trepeat\n\t\tlocal idx = random(1, #nums);\n\t\tlocal n = remove(nums, idx);\n\t\tcharmap[n] = char(n - 1);\n\tuntil #nums == 0;\n\n\tlocal prev_values = {}\n\tlocal function get_next_pseudo_random_byte()\n\t\tif #prev_values == 0 then\n\t\t\tstate_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832\n\t\t\trepeat\n\t\t\t\tstate_8 = state_8 * param_mul_8 % 257\n\t\t\tuntil state_8 ~= 1\n\t\t\tlocal r = state_8 % 32\n\t\t\tlocal n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r\n\t\t\tlocal rnd = floor(n % 1 * 2 ^ 32) + floor(n)\n\t\t\tlocal low_16 = rnd % 65536\n\t\t\tlocal high_16 = (rnd - low_16) / 65536\n\t\t\tlocal b1 = low_16 % 256\n\t\t\tlocal b2 = (low_16 - b1) / 256\n\t\t\tlocal b3 = high_16 % 256\n\t\t\tlocal b4 = (high_16 - b3) / 256\n\t\t\tprev_values = { b1, b2, b3, b4 }\n\t\tend\n\t\treturn table.remove(prev_values)\n\tend\n\n\tlocal realStrings = {};\n\tlocal STRINGS = setmetatable({}, {\n\t\t__index = realStrings;\n\t\t__metatable = nil;\n\t});\n  \tlocal function DECRYPT(str, seed)\n\t\tlocal realStringsLocal = realStrings;\n\t\tif(realStringsLocal[seed]) then else\n\t\t\tprev_values = {};\n\t\t\tlocal chars = charmap;\n\t\t\tstate_45 = seed % 35184372088832\n\t\t\tstate_8 = seed % 255 + 2\n\t\t\tlocal len = string.len(str);\n\t\t\trealStringsLocal[seed] = \"\";\n\t\t\tlocal prevVal = secret_key_8;\n\t\t\tfor i=1, len do\n\t\t\t\tprevVal = (string.byte(str, i) + get_next_pseudo_random_byte() + prevVal) % 256\n\t\t\t\trealStringsLocal[seed] = realStringsLocal[seed] .. chars[prevVal + 1];\n\t\t\tend\n\t\tend\n\t\treturn seed;\n\tend\n\n    local data = {}\n    for _, v in next, strings do\n        data[#data + 1] = STRINGS[DECRYPT(v[1], v[2])]:gsub(\"\\n\", '\\\\n')\n    end\n    print(table.concat(data, \"\\n\"))\nend";
  const File = "decrypt.lua";
  await fs.writeFile(File, codeStr);
  await new Promise(res => {
    const proc = spawn("luau", [File]);
    proc.stdout.on("data", a => {
      const data = a.toString().split("\n");
      const len = data.length;
      for (let i = 0; i < len - 1; i++) {
        const encoded = encrypted[i];
        const val = data[i].substring(0, data[i].length - 1);
        Clear(encoded);
        encoded.type = "StringLiteral";
        encoded.raw = "\"".concat(val, "\"");
      }
      res();
    });
    proc.stderr.on("data", a => {
      print("ERROR ".concat(a.toString()));
      res();
    });
    proc.on("error", a => console.error("[ERRORED] ".concat(a.toString())));
  });
  print("done ya bro");
  for (let i of searchIs(output, {
    type: "IndexExpression",
    base: stringsTable
  })) {
    const idx = i.index;
    Clear(i);
    for (let j in idx) i[j] = idx[j];
  }
  return output;
};