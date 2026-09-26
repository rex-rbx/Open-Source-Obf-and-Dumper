import { is, print, isWeird, search, searchIs, fixRaw, Clear, searchOr, solveMath } from '../mods/helper.js';
import query from '../mods/query.js';
import simpleAst from '../mods/simple-ast.js';
import indexCleaner from '../mods/indexCleaner.js';
import beautify from '../mods/beautifier.js';
export default (output, identifiers, dontLocalify = new Set()) => {
  const {
    Env,
    FunctionParams,
    RegTable,
    Parameters
  } = identifiers;
  const Registry = Object.create(null);
  let RegId = 0;
  const collectNodesInOrder = (root, predicate) => {
    const results = [];
    const seen = new WeakSet();
    const walk = node => {
      if (!node || typeof node !== "object") return;
      if (Array.isArray(node)) {
        for (const item of node) walk(item);
        return;
      }
      if (seen.has(node)) return;
      seen.add(node);
      if (predicate(node)) results.push(node);
      for (const key in node) walk(node[key]);
    };
    walk(root);
    return results;
  };
  let Yapping = 1;
  const GetId = val => {
    return {
      type: "Identifier",
      name: "arg" + val + (Yapping == 1 ? "" : "_" + Yapping)
    };
  };
  const VarargTemplate = {
    type: "CallExpression",
    base: Parameters.Unpack,
    arguments: [simpleAst.fieldsTable({
      type: "CallExpression",
      base: Parameters.Select,
      arguments: [{
        type: "NumericLiteral"
      }, {
        type: "CallExpression",
        base: Parameters.Unpack,
        arguments: [FunctionParams]
      }]
    })]
  };
  const SelectTemplate = {
    type: "CallExpression",
    base: {
      name: "select"
    },
    arguments: [{
      type: "NumericLiteral"
    }, {
      type: "VarargLiteral"
    }]
  };
  const UnpackTemplate = {
    type: "CallExpression",
    base: Parameters.Unpack,
    arguments: [{
      type: "TableConstructorExpression",
      fields: [{
        type: "TableValue"
      }]
    }]
  };
  for (let call of query(output, VarargTemplate)) {
    const start = call.arguments[0].fields[0].value.arguments[0];
    Clear(call);
    call.type = "CallExpression", call.base = {
      type: "Identifier",
      name: "select"
    }, call.arguments = [start, {
      type: "VarargLiteral",
      raw: "...",
      value: "..."
    }];
  }
  for (let call of query(output, UnpackTemplate)) {
    const args = call.arguments[0].fields[0].value;
    Clear(call);
    Object.assign(call, args);
  }
  for (let func of query(output, "FunctionDeclaration")) {
    const params = query(func.body, {
      type: "IndexExpression",
      base: FunctionParams,
      index: {
        type: "NumericLiteral"
      }
    }, {
      outsideOf: "FunctionDeclaration"
    });
    let max;
    for (let x of params) {
      const val = x.index.value;
      if (!max || val > max) max = val;
      Clear(x);
      Object.assign(x, GetId(val));
    }
    for (let i of query(func.body, SelectTemplate)) {
      const from = i.arguments[0].value - (max ?? 1);
      if (from == 1) {
        Clear(i);
        i.type = "VarargLiteral", i.raw = "...", i.value = "...";
      } else i.arguments[0].value = from, i.arguments[0].raw = '' + from;
    }
    if (!max) continue;
    const args = [];
    for (let i = 0; i < max; i++) args.push(GetId(i + 1));
    func.parameters = [...args, {
      type: "VarargLiteral",
      raw: "...",
      value: "..."
    }];
    Yapping++;
  }
  for (let assign of query(output, {
    type: "AssignmentStatement",
    init: [FunctionParams]
  })) {
    assign.init[0] = {
      type: "TableConstructorExpression",
      fields: [{
        type: "TableValue",
        value: {
          type: "VarargLiteral",
          value: "...",
          raw: "..."
        }
      }]
    };
  }
  const Registers = collectNodesInOrder(output, expression => is(expression, {
    type: "IndexExpression",
    base: RegTable
  }));
  const getRegisterIndex = expression => {
    let index = expression.index;
    if (index.type == "IndexExpression") {
      const base = index.base;
      if (base.type == "TableConstructorExpression" && index.index.type == "NumericLiteral") {
        const f = base.fields[index.index.value - 1];
        if (f?.type == "TableValue") index = f.value;
      }
    }
    if (index?.type != "NumericLiteral") return null;
    return index.raw ?? String(index.value);
  };
  for (let expression of Registers) {
    const key = getRegisterIndex(expression);
    if (key == null) continue;
    const Reg = Registry[key] ??= "r" + ++RegId;
    Clear(expression);
    expression.type = "Identifier", expression.name = Reg;
  }
  for (let ass of query(output, "AssignmentStatement")) {
    if (!ass.init.filter(a => a.type != "NilLiteral").length && !ass.variables.filter(a => a.type != "Identifier").length) Clear(ass);else if (ass.variables.length == 1 && ass.init[0]?.type == "FunctionDeclaration") {
      if (ass.variables[0].type != "Identifier") {
        dontLocalify.add(ass);
        continue;
      }
      ass.type = "FunctionDeclaration";
      ass.isLocal = true;
      ass.identifier = ass.variables[0];
      for (let i in ass.init[0]) ass[i] = ass.init[0][i];
    }
  }
  indexCleaner(output, Env);
  for (let idx2 of query(output, "IndexExpression").filter(a => a.base.name == Env.name)) {
    idx2.base.name = "Env";
  }
  const evalCondition = node => {
    if (!node || typeof node !== 'object') return undefined;
    switch (node.type) {
      case 'BooleanLiteral':
        return node.value;
      case 'NilLiteral':
        return false;
      case 'NumericLiteral':
        return true;
      case 'StringLiteral':
        return true;
      case 'BinaryExpression':
        {
          try {
            const res = solveMath(node.left, node.operator, node.right);
            if (typeof res === 'boolean') return res;
            if (typeof res === 'number') return true;
          } catch (e) {}
          return undefined;
        }
      case 'LogicalExpression':
        {
          const l = evalCondition(node.left);
          if (node.operator === 'and') {
            if (l === false) return false;
            const r = evalCondition(node.right);
            if (r === undefined) return undefined;
            return Boolean(r);
          } else {
            if (l === true) return true;
            const r = evalCondition(node.right);
            if (r === undefined) return undefined;
            return Boolean(r);
          }
        }
      case 'UnaryExpression':
        {
          if (node.operator === 'not') {
            const a = evalCondition(node.argument);
            if (a === undefined) return undefined;
            return !a;
          }
          return undefined;
        }
      default:
        return undefined;
    }
  };
  for (const ifStat of query(output, 'IfStatement')) {
    const firstClause = ifStat.clauses && ifStat.clauses[0];
    if (!firstClause || !firstClause.condition) continue;
    const val = evalCondition(firstClause.condition);
    if (val === undefined) continue;
    if (val === true) {
      const body = firstClause.body || [];
      Clear(ifStat);
      ifStat.type = 'DoStatement';
      ifStat.body = body;
    } else {
      const elseClause = (ifStat.clauses || []).find(c => !c.condition);
      if (elseClause) {
        const body = elseClause.body || [];
        Clear(ifStat);
        ifStat.type = 'DoStatement';
        ifStat.body = body;
      } else {
        Clear(ifStat);
      }
    }
  }
};