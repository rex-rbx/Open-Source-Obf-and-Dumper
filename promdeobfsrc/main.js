import * as fs from "fs/promises";
import beautify from "./mods/beautifier.js";
import { parse, defaultOptions } from "./mods/luaparse.js";
import simpleAst from "./mods/simple-ast.js";
import { inline, setInlineOptions } from "./mods/inlinev4.js";
import localify from "./mods/localify.js";
import { is, search, searchIs, print } from "./mods/helper.js";
import indexCleaner from "./mods/indexCleaner.js";
import indexFixer from "./mods/indexFixer.js";
import query from "./mods/query.js";
import { LuauState } from "luau-web";
import _stepFunctions from "./reversing/functions.js";
import _stepConstarray from "./reversing/constarray.js";
import _stepUncff from "./reversing/uncff.js";
import _stepRepeatfix from "./reversing/repeatfix.js";
import _stepCleaner from "./reversing/cleaner.js";
import _stepDecrypt from "./reversing/decrypt.js";
const _reversing = {
  functions: _stepFunctions,
  constarray: _stepConstarray,
  uncff: _stepUncff,
  repeatfix: _stepRepeatfix,
  cleaner: _stepCleaner,
  decrypt: _stepDecrypt
};
const runStep = (path, ...args) => _reversing[path](...args);
const Do = a => a();
const Dont = (...a) => {};
defaultOptions.comments = false;
const deobfuscate = async src => {
  if (!src) throw new Error("No source provided to deobfuscate()");
  if (typeof src != "string") throw new Error("Source must be a string.");
  const Options = {
    fork: null,
    iterStats: []
  };
  const content = beautify(src);
  const start = performance.now();
  if (/getgenv\(\)\[.+\] = function\(/.test(content)) {
    Options.fork = "25ms";
  }
  let output = [];
  let fileAst;
  try {
    fileAst = parse(content);
  } catch (err) {
    console.error("Unable to parse AST, message: ".concat(err));
    return "Unable to parse AST.";
  }
  const State = await LuauState.createAsync();
  query(fileAst, "CompoundAssignmentStatement").forEach(stat => {
    const {
      variable,
      op,
      value
    } = stat;
    Object.assign(stat, {
      type: "AssignmentStatement",
      variables: [variable],
      init: [{
        type: "BinaryExpression",
        operator: op,
        left: variable,
        right: value
      }]
    });
  });
  const MainFunctions = searchIs(fileAst, {
    type: "CallExpression",
    base: {
      type: "FunctionDeclaration"
    },
    arguments: []
  });
  const VarargTable = simpleAst.varargTable();
  let MainFunction, EnvIdx;
  for (let f of MainFunctions) {
    if (f.arguments.find(lastArg => is(lastArg, VarargTable))) {
      MainFunction = f;
      for (let i = 0; i < f.arguments.length; i++) {
        const arg = f.arguments[i];
        if (is(arg, {
          type: "LogicalExpression",
          operator: "or",
          left: {
            left: {
              name: "getfenv"
            }
          }
        })) {
          EnvIdx = i;
          break;
        }
      }
      break;
    }
  }
  if (!MainFunction) {
    await fs.writeFile("formatted.lua", beautify(fileAst));
    throw new Error("Unable to locate MainFunction :(");
  }
  const Env = MainFunction.base.parameters[EnvIdx];
  if (!Env) throw new Error("Unable to find the Env parameter");
  let WhileStat,
    Pc,
    ReturnVar,
    Upvalues,
    FunctionParams,
    Unpack,
    Select = {
      type: "Identifier",
      name: "select"
    },
    StartOpc,
    Dispatchers = {};
  Do(() => {
    let Counter = 0;
    for (let Param of MainFunction.arguments) {
      if (is(Param, {
        type: "LogicalExpression",
        operator: "or",
        left: {
          name: "unpack"
        }
      })) Unpack = MainFunction.base.parameters[Counter];else if (is(Param, {
        name: "select"
      })) Select = MainFunction.base.parameters[Counter];
      Counter++;
    }
    const Body = MainFunction.base.body;
    const Last = Body[Body.length - 1];
    if (is(Last, {
      type: "ReturnStatement",
      arguments: [{
        base: {
          type: "CallExpression",
          base: {
            type: "Identifier"
          },
          arguments: [{
            type: "NumericLiteral"
          }, {
            type: "TableConstructorExpression"
          }]
        }
      }]
    })) StartOpc = Last.arguments[0].base.arguments[0].value;
  });
  for (let {
    parameters,
    body
  } of search(MainFunction, "FunctionDeclaration")) {
    const Param = parameters[0];
    const LastStat = body[body.length - 1],
      LastStat_2 = body[body.length - 2];
    if (is(LastStat, {
      type: "ReturnStatement",
      arguments: [{
        type: "CallExpression",
        base: Unpack
      }]
    }) && is(LastStat_2, {
      type: "AssignmentStatement",
      init: [{
        type: "UnaryExpression",
        operator: "#"
      }],
      variables: [Param]
    })) {
      ReturnVar = LastStat.arguments[0].arguments[0], Pc = Param, Upvalues = parameters[2], FunctionParams = parameters[1];
      for (let stat of body) if (stat.type == "WhileStatement") {
        WhileStat = stat;
        break;
      }
    }
  }
  const {
    RegTable
  } = runStep("functions", MainFunction.base, Dispatchers);
  output = await runStep("constarray", fileAst, output, State, Options);
  if (process.argv[4]) await fs.writeFile("formatted.lua", beautify(fileAst));
  Do(() => {
    const IfStat = search(WhileStat, "IfStatement")[0] || WhileStat;
    const data = runStep("uncff", IfStat, StartOpc, {
      pc: Pc,
      dispatchers: Dispatchers,
      returnVar: ReturnVar,
      env: Env,
      upv: Upvalues,
      params: FunctionParams,
      reg: RegTable
    });
    for (let i of data) output.push(i);
  });
  runStep("repeatfix", output);
  const dontLocalify = new Set();
  if (!process.argv[5]) {
    setInlineOptions({
      simplifyCalls: true,
      RegTable,
      Unpack: Unpack?.name
    });
    try {
      inline(output);
    } catch (err) {
      console.error("UNABLE TO INLINE", err);
    }
    try {
      indexFixer(output);
    } catch (err) {
      console.error("failed to fix indexes", err);
    }
    runStep("cleaner", output, {
      Env,
      FunctionParams,
      RegTable,
      Parameters: {
        Select,
        Unpack
      }
    }, dontLocalify);
  }
  await new Promise(async res => {
    try {
      const s = performance.now();
      output = await runStep("decrypt", output, Options.iterStats, {
        upvalues: Upvalues,
        regtable: RegTable
      }, State);
      print("Successfully decrypted strings in", Math.floor(performance.now() - s), "ms!");
    } catch (err) {
      const m = "Encrypt strings is off";
      if (err.message == m) print(m);else console.error("Errored while decrypting strings:", err);
    }
    res(1);
  });
  indexCleaner(output, Env);
  if (!process.argv[5]) localify(output, dontLocalify);
  try {
    indexFixer(output);
  } catch (err) {
    console.error("failed to fix final indexes", err);
  }
  print("Done in", (performance.now() - start).toFixed(2), "ms.");
  return beautify([{
    type: "LocalStatement",
    variables: [simpleAst.ident("Env")],
    init: [{
      type: "CallExpression",
      base: simpleAst.ident("getfenv"),
      arguments: []
    }]
  }, {
    type: "LocalStatement",
    variables: [RegTable],
    init: [simpleAst.emptyTable()]
  }].concat(output), {
    solveMath: true
  });
};
export default deobfuscate;