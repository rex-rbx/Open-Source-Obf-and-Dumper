import { is, print, Clear, clone, isWeird, fixString } from './helper.js';
import query from './query.js';
import * as fs from 'fs';
import beautify from './beautifier.js';
import { parse, defaultOptions } from './luaparse.js';
const DEBUG = process.argv[1].includes("inline") && process.argv[2];
let settings = {
  simplifyCalls: false,
  simpleInlining: false,
  RegTable: null,
  Unpack: "unpack"
};
const RESET = "\x1b[0m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const COLORS = {
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  magenta: "\x1b[35m",
  blue: "\x1b[0;94m",
  gray: "\x1b[90m"
};
const ACTION_STYLES = {
  Inlining: {
    color: COLORS.green,
    symbol: "✓",
    label: "INLINE"
  },
  Reassign: {
    color: COLORS.cyan,
    symbol: "→",
    label: "REASSIGN"
  },
  "Not inlining": {
    color: COLORS.red,
    symbol: "✗",
    label: "SKIP"
  },
  "Cleared data": {
    color: COLORS.magenta,
    symbol: "~",
    label: "CLEAR"
  },
  "Can't inline": {
    color: COLORS.red,
    symbol: "✗",
    label: "CANT INLINE"
  },
  "dont change": {
    color: COLORS.yellow,
    symbol: "!",
    label: "DONT CHANGE"
  },
  transform: {
    color: COLORS.cyan,
    symbol: "→",
    label: "REWRITE"
  },
  test: {
    color: COLORS.blue,
    symbol: "?",
    label: "TEST"
  }
};
const debug = DEBUG ? (nest, action, ...args) => {
  const indent = "  ".repeat(nest);
  const level = "".concat(COLORS.gray, "[L").concat(nest, "]").concat(RESET);
  const style = ACTION_STYLES[action] ?? {
    color: COLORS.gray,
    symbol: "·",
    label: action.padEnd(8)
  };
  const coloredLabel = "".concat(style.color).concat(BOLD).concat(style.symbol, " ").concat(style.label).concat(RESET);
  const rest = args.map((a, i) => {
    if (i === 0) return "".concat(BOLD).concat(a).concat(RESET);
    if (typeof a === "string" && /Expression|Statement|Literal|Identifier|Constructor/.test(a)) return "".concat(DIM).concat(a).concat(RESET);
    return a;
  });
  const distance = 16;
  const spaces = " ".repeat(Math.abs(distance - style.label.length));
  console.log("".concat(indent).concat(level, " ").concat(coloredLabel).concat(spaces), ...rest);
} : () => {};
const assignPattern = {
  init: [],
  variables: []
};
const dontInline = new Set(["TableConstructorExpression"]);
const simple = new Set(["NumericLiteral", "StringLiteral", "BooleanLiteral", "VarargLiteral", "NilLiteral", "Identifier"]);
const dontChangeList = new Set();
const dontTouch = new Set();
const minors = new Set();
const wasInlined = new Set();
const nonerz = new Set(["CallExpression", "NamecallExpression"]);
const tableAssigns = new Set();
const usedInDifferentScopesList = new Set();
const globalDifferentScopes = new Set();
const definedInScopeGlobal = {};
const isSimple = a => simple.has(a?.type);
const isUnusedRemovableTable = a => {
  if (a?.type != "TableConstructorExpression") return false;
  const fields = a.fields ?? [];
  if (fields.length == 0 || !fields.find(a => a.value && !isSimple(a.value))) return true;
  return fields.length == 1 && fields[0]?.type == "TableValue" && fields[0].value?.type == "VarargLiteral";
};
const needsInline = a => !dontInline.has(a.type);
const inline = (ast, values = {}, uses = {}, nest = 0, newAssign, outer = new Set(), ...extra) => {
  if (!Array.isArray(ast)) return;
  const dontChange = extra[0] ?? dontChangeList;
  const usedInDifferentScopes = extra[1] ?? usedInDifferentScopesList;
  const definedInScope = extra[2] ?? definedInScopeGlobal;
  const assignedInThisScope = new Set();
  const tableAssigns = {};
  const Debug = (...a) => debug(nest, ...a);
  const replaceAll = (list, val) => {
    for (let i of list) if (!dontTouch.has(i)) Object.assign(i, val);
  };
  const clearStat = (Variable, why) => {
    Debug("Cleared data", Variable, why ?? "no reason given");
    delete values[Variable];
    delete uses[Variable];
  };
  const isDifferentScope = name => {
    const originalAst = definedInScope[name];
    if (originalAst && originalAst != ast) return true;
    return false;
  };
  const countVarUse = (val, u, z) => {
    const name = val.name;
    if (isDifferentScope(name)) {
      usedInDifferentScopes.add(name);
      globalDifferentScopes.add(val);
    }
    const parent = u ?? uses;
    const list = parent[name];
    if (list) list.push(val);else if (z) parent[name] = [val];
  };
  const countUse = (val, ...a) => {
    if (val.type == "Identifier") countVarUse(val);else countUses(val, undefined, undefined, ...a);
  };
  const countUses = (stat, list, x, caspoor) => {
    const iterateOver = query(stat, "Identifier", {
      dontTouch: caspoor
    });
    for (const a of iterateOver) countVarUse(a, list, x);
  };
  const getInit = (valueStat, variable) => {
    const vars = valueStat.variables;
    if (!vars) return [null, -1];
    let idx = 0,
      found = vars.length == 1;
    if (vars.length > 1) for (let i = vars.length - 1; i >= 0; i--) {
      const v = vars[i];
      if (v.name == variable) {
        found = true;
        idx = i;
        break;
      }
    }
    if (!found) return [null, -1];
    const val = valueStat.init[idx] ?? {
      type: "NilLiteral",
      raw: "nil"
    };
    return [val, idx];
  };
  const inlineStat = (variable, oldUses, valueStat, y) => {
    oldUses ??= uses[variable];
    valueStat ??= values[variable];
    const [idx, val] = y;
    const vars = valueStat.variables,
      init = valueStat.init;
    valueStat.init = init.filter(a => a != init[idx]);
    valueStat.variables = vars.filter(a => a != vars[idx]);
    if (valueStat.variables.length == 0) Clear(valueStat);
    replaceAll(oldUses, val);
    clearStat(variable, "inlineStat called");
  };
  const removeFromValue = (value, idx) => {
    const init = value.init[idx],
      variable = value.variables[idx];
    value.init = value.init.filter(a => a != init);
    if (!value.init.length) {
      return Clear(value);
    }
    value.variables = value.variables.filter(a => a != variable);
  };
  const handleFunc = init => {
    handleBody(init, init.parameters, true);
  };
  const getValue = thing => {
    if (thing.type == "Identifier") {
      const variable = thing.name;
      const value = values[variable];
      if (value) return getInit(value, variable)[0];
    }
    return thing;
  };
  const handlePass = (inits, stat) => {
    for (let init of inits ?? []) {
      const dontTouchSet = new Set();
      let funcDetected;
      switch (init.type) {
        case null:
          break;
        case "CallExpression":
          {
            if (stat.variables.length > 1) {
              for (let {
                name
              } of stat.variables) {
                const u = uses[name];
                if (name && u) {
                  inlineThing(values[name], u, name, true);
                  addToDiddyList(name, "CallExpression init");
                }
              }
              return;
            }
            break;
          }
        case "FunctionDeclaration":
          funcDetected = true;
          handleFunc(init);
          break;
        case "LogicalExpression":
          for (let x of query(init, "FunctionDeclaration")) {
            handleFunc(x);
            dontTouchSet.add(x);
          }
          break;
      }
      if (!funcDetected) countUse(init, dontTouchSet);
    }
    let i = -1;
    for (let variable of stat.variables) {
      i++;
      if (variable.type == "MemberExpression" || variable.type == "IndexExpression") {
        const base = variable.base;
        if (base?.type == "Identifier") {
          let list = tableAssigns[base.name];
          const key = variable.type == "MemberExpression" ? variable.identifier : variable.index;
          if (isSimple(key) && key.type != "Identifier") {
            if (!list) {
              list = {};
              tableAssigns[base.name] = list;
            }
            const idx = key.value ?? key.name;
            if (idx || idx == null) list[idx] = null;else list[idx] = inits[i];
          }
        }
        countUse(variable);
        continue;
      }
      if (is(variable, inits[i])) {
        countUses(variable);
        continue;
      }
      const name = variable.name;
      assignedInThisScope.add(name);
      if (newAssign) newAssign.add(name);
      const kapara = values[name],
        oldUses = uses[name];
      if (kapara) {
        Debug("Reassign", name, "reassigned to", inits[i]);
        inlineThing(kapara, oldUses, name, !outer.has(name));
        dontChange.delete(name);
        delete definedInScope[name];
      } else definedInScope[name] = ast;
      values[name] = stat;
      if (!oldUses || kapara) uses[name] = [];
    }
  };
  const inlineThing = (value, list, variable, reassigned, iReallyDc, skip) => {
    if (!value || !value.init) return Debug("Not inlining", variable, ": no value", value);
    const length = list.length;
    const [init, idx] = getInit(value, variable);
    if (idx == -1) {
      Debug("ERROR", "Unable to get init of variable", variable);
      return;
    }
    if (!skip) {
      const name = init.name;
      if (init.type == "Identifier" && uses[name]?.length == 1) {
        if (dontChange.has(name)) {
          Debug("Not inlining", "issue #4 (".concat(variable, " = ").concat(name, " and ").concat(name, " has 1 use), however '").concat(name, "' is in dontChange."));
          if (!reassigned) clearStat(name, "issue #4 but dontchange");
          return inlineThing(value, list, variable, reassigned, iReallyDc, true);
        }
        Debug("test", "yoo issue #4 (".concat(variable, " = ").concat(name, " and ").concat(name, " has 1 use.), probably ").concat(reassigned ? "returning" : "inlining ".concat(name)));
        const val = values[name];
        const valueOfInit = val?.type ? getInit(val, name)[0] : null;
        if (query(valueOfInit, value.variables[idx]).length) {
          Debug("Not inlining", variable, "issue #4 cycle");
          return;
        }
        if (reassigned) return;
        value.init[idx] = valueOfInit;
        return true;
      }
      const canInline = needsInline(init);
      if (dontChange.has(variable) && !reassigned && !(length == 0 && isUnusedRemovableTable(init))) {
        Debug("dont change", variable, init.type);
        return;
      }
      if (iReallyDc) {
        Debug("Inlining", "Forcefully inlining", variable, init.type);
        inlineStat(variable, list, value, [idx, init]);
        return true;
      }
      if (length == 0) {
        if (settings.simplifyCalls && value.variables.length == 1 && init.type == "CallExpression") {
          Clear(value);
          value.type = "CallStatement";
          value.expression = init;
          dontChange.delete(variable);
          clearStat(variable, "callexpression->callstatement deletes the variable");
          return Debug("transform", variable, "CallExpression->CallStatement");
        } else if (isUnusedRemovableTable(init)) {
          inlineStat(variable, list, value, [idx, init]);
          Debug("transform", variable, "Dropped unused table");
          return true;
        } else if (reassigned && isSimple(init)) {
          removeFromValue(value, idx);
        }
        return Debug("Not inlining", variable, "(has 0 uses)", init.type, reassigned ? "(reassigned)" : "(wasnt reassigned)");
      }
      if (!canInline) {
        if (isDifferentScope(variable) || list.length == 1 && globalDifferentScopes.has(list[0])) return Debug("Can't inline", variable, init.type, length);
      }
    }
    const simple = isSimple(init);
    if (length != 1 && (!simple || settings.simpleInlining)) {
      return Debug("Not inlining", variable, "".concat(length, " uses (").concat(init.type, ")"));
    }
    if (outer.has(variable) && !newAssign.has(variable)) return Debug("Not inlining", variable, "is in outer vars");
    Debug("Inlining", variable, init.type, "(".concat(list.length, " uses)"));
    inlineStat(variable, list, value, [idx, init]);
    return true;
  };
  const finallyInline = (uses, values) => {
    for (let variable in uses) {
      Debug("test", "Finally inlining", variable);
      const list = uses[variable];
      const value = values[variable];
      inlineThing(value, list, variable);
    }
  };
  const addToDiddyList = (v, r) => {
    Debug("dont change", "added", v, "to the dontChange list", "(".concat(r ?? "no reason specified", ")"));
    dontChange.add(v);
  };
  const thoseWhoChangedButSet = (vals, innerValues) => {
    if (innerValues) {
      for (let v of vals) {
        if (innerValues[v]?.length) clearStat(v, "thoseWhoChanged (is in innerValues)");
      }
      return;
    }
    for (let v of vals) addToDiddyList(v, "thoseWhoChanged (plain add)");
  };
  const mergeInto = (target, source) => {
    for (let i = 0; i < source.length; i++) target.push(source[i]);
  };
  const mergeUses = (from, exclude) => {
    if (exclude) {
      for (let v in uses) if (!exclude.has(v)) mergeInto(uses[v], from[v] ?? []);
      return;
    }
    for (let v in uses) mergeInto(uses[v], from[v] ?? []);
  };
  const makeEmptyCopy = () => {
    const yap = {};
    for (let v in values) yap[v] = [];
    return yap;
  };
  const countStatUses = stat => {
    for (let i in stat) {
      if (i == "body") continue;
      const val = stat[i];
      if (!val) continue;
      countUse(val);
    }
  };
  const handleBody = (stat, ignore = [], isFunc) => {
    countStatUses(stat);
    const assigned = new Set();
    const newUses = makeEmptyCopy();
    const newValues = clone(values);
    const newOuter = new Set(assignedInThisScope);
    const newDontChange = new Set(dontChange);
    for (let i of ignore) {
      if (typeof i != "string") i = i.name;
      newDontChange.add(i);
      delete newValues[i];
      delete newUses[i];
    }
    Debug("test", "entering", stat.type);
    inline(stat.body, newValues, newUses, nest + 1, assigned, newOuter, newDontChange);
    Debug("test", "exited", stat.type);
    if (isFunc) {
      mergeUses(newUses, assigned);
      return;
    }
    const reassignedWithPendingUses = new Set();
    for (let v of assigned) if (newUses[v]?.length > 0) reassignedWithPendingUses.add(v);
    thoseWhoChangedButSet(assigned, newUses);
    mergeUses(newUses, reassignedWithPendingUses);
  };
  for (let stat of ast) {
    if (!stat) continue;
    if (stat.type == "CompoundAssignmentStatement") {
      const {
        variable,
        op,
        value
      } = stat;
      Clear(stat);
      stat.type = "AssignmentStatement";
      stat.variables = [variable];
      stat.init = [{
        type: "BinaryExpression",
        operator: op,
        left: variable,
        right: value
      }];
      dontTouch.add(stat.variables[0]);
      dontTouch.add(stat.init[0]);
      handlePass(stat.init, stat);
    } else if (is(stat, assignPattern)) handlePass(stat.init, stat);else {
      switch (stat.type) {
        case "ForGenericStatement":
          for (const {
            name
          } of stat.variables) {
            const usages = uses[name];
            if (usages) {
              inlineThing(values[name], usages, name);
              clearStat(name, "in ForGenericStatement");
            }
          }
          break;
        case "ForNumericStatement":
          {
            handleBody(stat, [stat.variable.name]);
            continue;
          }
        case "IfStatement":
          {
            for (let clause of stat.clauses) {
              handleBody(clause);
            }
            continue;
          }
        case "WhileStatement":
          {
            const cond = stat.condition;
            const dontChangeV1 = dontChange.has(cond.name);
            handleBody(stat);
            if (!dontChangeV1) dontChange.delete(cond.name);
            continue;
          }
        case "RepeatStatement":
          {
            handleBody(stat);
            continue;
          }
        case "ReturnStatement":
          {
            countUses(stat);
            continue;
          }
      }
      (stat.body ? handleBody : countUses)(stat);
    }
  }
  finallyInline(uses, values);
  return values;
};
if (DEBUG) {
  defaultOptions.comments = false;
  const body = parse(fs.readFileSync("input.lua").toString());
  const s = performance.now();
  inline(body.body);
  const t = performance.now() - s;
  fs.writeFileSync("inlined.lua", beautify(body, {
    solveMath: false
  }));
  print("took", Number(t.toFixed(2)), "ms to beautify");
}
export const setInlineOptions = a => {
  settings = a;
};
export { inline };
export default {
  inline,
  setInlineOptions
};