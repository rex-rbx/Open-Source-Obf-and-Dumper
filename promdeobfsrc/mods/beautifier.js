import luaparse from './luaparse.js';
import { solveMath, clone, fixString } from './helper.js';
const parse = luaparse.parse;
const settings = {
  solveMath: true
};
const defaultSettings = clone(settings);
var PRECEDENCE = {
  'or': 1,
  'and': 2,
  '<': 3,
  '>': 3,
  '<=': 3,
  '>=': 3,
  '~=': 3,
  '==': 3,
  '..': 5,
  '+': 6,
  '-': 6,
  '*': 7,
  '/': 7,
  '%': 7,
  'unarynot': 8,
  'unary#': 8,
  'unary-': 8,
  '^': 10
};
const isNan = a => typeof a == "number" && !(a < 0) && !(a > 0) && a != 0;
var each = function (array, fn) {
  var index = -1;
  var length = array.length;
  var max = length - 1;
  while (++index < length) {
    fn(array[index], index < max);
  }
};
var hasOwnProperty = {}.hasOwnProperty;
var extend = function (destination, source) {
  var key;
  if (source) {
    for (key in source) {
      if (hasOwnProperty.call(source, key)) {
        destination[key] = source[key];
      }
    }
  }
  return destination;
};
const joinStatements = (a, b, separator) => a + (separator ?? " ") + b;
const formatBase = function (base, indent = 0) {
  var result = '';
  var type = base.type;
  var needsParens = base.inParens || type == 'BinaryExpression' || type == 'FunctionDeclaration' || type == 'TableConstructorExpression' || type == 'LogicalExpression' || type == 'StringLiteral' || type == "VarargLiteral";
  if (needsParens) {
    result += '(';
  }
  result += formatExpression(base, null, indent);
  if (needsParens) {
    result += ')';
  }
  return result;
};
const _visiting = new WeakSet();
var formatExpression = function (expression, options, indent = 0) {
  if (!expression || typeof expression !== 'object') return '';
  if (_visiting.has(expression)) return 'CYCLE_REFERENCE';
  _visiting.add(expression);
  try {
    return _formatExpression(expression, options, indent);
  } finally {
    _visiting.delete(expression);
  }
};
var _formatExpression = function (expression, options, indent = 0) {
  if (!expression || typeof expression !== 'object') return '';
  options = extend({
    'precedence': 0
  }, options);
  var result = '';
  var currentPrecedence;
  var associativity;
  var operator;
  const tab = "    ".repeat(indent);
  const nextTab = "    ".repeat(indent + 1);
  var expressionType = expression.type;
  if (expressionType == 'Identifier') {
    result = expression.name;
  } else if (expressionType == 'StringLiteral' || expressionType == 'NumericLiteral' || expressionType == 'BooleanLiteral' || expressionType == 'NilLiteral' || expressionType == 'VarargLiteral') {
    if (expressionType == "StringLiteral") {
      const raw = expression.raw;
      if (typeof raw == "string" && raw.length >= 2) {
        const quote = raw.substring(0, 1);
        if ((quote == '"' || quote == "'") && raw.endsWith(quote)) return "".concat(quote).concat(fixString(raw.substring(1, raw.length - 1), quote)).concat(quote);
        return raw;
      }
      if (typeof expression.value == "string") return "\"" + fixString(expression.value, "\"") + "\"";
      return '""';
    }
    result = expression.raw;
  } else if (expressionType == 'LogicalExpression' || expressionType == 'BinaryExpression') {
    operator = expression.operator;
    currentPrecedence = PRECEDENCE[operator];
    associativity = 'left';
    const solved = settings.solveMath && expressionType == "BinaryExpression" ? solveMath(expression.left, operator, expression.right) : undefined;
    if (solved != undefined && solved != null) {
      if (solved == Infinity) return "math.huge";
      if (isNan(solved)) return "0 / 0";
      if (typeof solved == "object") return formatExpression(solved, null, indent);
      return '' + solved;
    }
    result = formatExpression(expression.left, {
      'precedence': currentPrecedence,
      'direction': 'left',
      'parent': operator
    }, indent);
    result = joinStatements(result, operator);
    result = joinStatements(result, formatExpression(expression.right, {
      'precedence': currentPrecedence,
      'direction': 'right',
      'parent': operator
    }, indent));
    if (operator == '^' || operator == '..') {
      associativity = "right";
    }
    if (currentPrecedence < options.precedence || currentPrecedence == options.precedence && associativity != options.direction && options.parent != '+' && !(options.parent == '*' && (operator == '/' || operator == '*'))) {
      result = '(' + result + ')';
    }
  } else if (expressionType == 'UnaryExpression') {
    operator = expression.operator;
    currentPrecedence = PRECEDENCE['unary' + operator];
    result = operator + (operator == "not" ? " " : "") + formatExpression(expression.argument, {
      'precedence': currentPrecedence
    }, indent);
    if (currentPrecedence < options.precedence && !(options.parent == '^' && options.direction == 'right')) {
      result = '(' + result + ')';
    }
  } else if (expressionType == 'CallExpression') {
    result = formatBase(expression.base, indent) + '(';
    const args = [];
    each(expression.arguments, argument => args.push(formatExpression(argument, null, indent)));
    result += args.join(", ");
    result += ')';
  } else if (expressionType == 'TableCallExpression') {
    result = formatBase(expression.base, indent + 1) + formatExpression(expression.arguments, null, indent);
  } else if (expressionType == 'StringCallExpression') {
    const argument = expression.base;
    result = formatBase(argument, indent) + formatExpression(expression.argument, null, indent);
  } else if (expressionType == 'IndexExpression') {
    const base = expression.base,
      index = expression.index;
    if (base.type == "TableConstructorExpression" && index.type == "NumericLiteral") {
      const f = base.fields[index.value - 1];
      if (f?.type == "TableValue") return formatExpression(f.value, null, indent);
    }
    result = formatBase(base, indent);
    result += '[' + formatExpression(index, null, indent) + ']';
  } else if (expressionType == 'MemberExpression') {
    result = formatBase(expression.base, indent) + expression.indexer + formatExpression(expression.identifier, null, indent);
  } else if (expressionType == "NamecallExpression") {
    const method = expression.method;
    result = "".concat(formatBase(expression.base, indent), ":").concat(formatExpression({
      type: "CallExpression",
      base: typeof method == "string" ? {
        type: "Identifier",
        name: method
      } : method,
      arguments: expression.args
    }, null, indent));
  } else if (expressionType == 'FunctionDeclaration') {
    result = 'function(';
    if (expression.parameters.length) {
      each(expression.parameters, function (parameter, needsComma) {
        result += parameter.name || parameter.value;
        if (needsComma) result += ', ';
      });
    }
    result += ')';
    result = joinStatements(result, formatStatementList(expression.body, indent + 1), "\n");
    result = joinStatements(result, "\n" + tab + "end");
  } else if (expressionType == 'TableConstructorExpression') {
    if (expression.fields.length == 1 && expression.fields[0].value?.type == "VarargLiteral") return "{...}";
    const stuff = [];
    each(expression.fields, function (field) {
      if (field.type == 'TableKey') {
        stuff.push('[' + formatExpression(field.key, null, indent + 1) + '] = ' + formatExpression(field.value, null, indent + 1));
      } else if (field.type == 'TableValue') {
        stuff.push(formatExpression(field.value, null, indent + 1));
      } else {
        stuff.push(formatExpression(field.key) + ' = ' + formatExpression(field.value, null, indent + 1));
      }
    });
    const line = "\n" + nextTab;
    result = stuff.length == 0 ? "{}" : "{".concat(line).concat(stuff.join("," + line), "\n").concat(tab, "}");
  } else if (expressionType == "InterpolatedStringExpression") {
    for (let x of expression.parts) result += x.type == "StringLiteral" ? x.value : "{".concat(formatExpression(x), "}");
    result = "`".concat(result, "`");
  } else {
    return '';
    throw TypeError('Unknown expression type: `' + expressionType + '`');
  }
  if (expression.inParens) return "(".concat(result, ")");
  return result;
};
var formatStatementList = function (body, indent = 0) {
  const stats = [];
  if (!body) {
    console.log("no body given to formatStatementList!");
    return "";
  }
  if (body.length == 0) return "";
  each(body, stat => {
    if (!stat || !stat.type) return;
    stats.push(formatStatement(stat, indent));
  });
  const tab = "    ".repeat(indent);
  let joined = "";
  let i = 0,
    length = stats.length;
  for (let stat of stats) {
    i++;
    const isComment = stat.startsWith("--");
    joined += stat + (!isComment ? ";" : "") + (i == length ? "" : "\n" + tab);
  }
  return tab + joined;
};
var formatStatement = function (statement, indent = 0) {
  if (!statement || !statement.type) return '';
  var result = '';
  var statementType = statement.type;
  const tab = "    ".repeat(indent);
  const newline = "\n" + tab;
  const end = newline + "end";
  if (statementType == 'AssignmentStatement') {
    each(statement.variables, function (variable, needsComma) {
      result += formatExpression(variable, null, indent);
      if (needsComma) result += ', ';
    });
    result += ' = ';
    each(statement.init, function (init, needsComma) {
      result += formatExpression(init, null, indent);
      if (needsComma) result += ', ';
    });
  } else if (statementType == 'LocalStatement') {
    result = 'local ';
    each(statement.variables, function (variable, needsComma) {
      result += variable.name;
      if (needsComma) {
        result += ', ';
      }
    });
    if (statement.init.length) {
      result += ' = ';
      each(statement.init, function (init, needsComma) {
        result += formatExpression(init, null, indent);
        if (needsComma) {
          result += ', ';
        }
      });
    }
  } else if (statementType == 'CallStatement') {
    result = formatExpression(statement.expression, null, indent);
  } else if (statementType == 'IfStatement') {
    result = joinStatements('if', formatExpression(statement.clauses[0].condition, null, indent));
    result += " then";
    const clause = statement.clauses[0].body;
    result += clause.length ? "\n" + formatStatementList(clause, indent + 1) : "";
    each(statement.clauses.slice(1), function (clause) {
      if (clause.condition) {
        result = joinStatements(result, 'elseif', newline);
        result = joinStatements(result, formatExpression(clause.condition, null, indent));
        result = joinStatements(result, 'then');
      } else {
        result = joinStatements(result, 'else', newline);
      }
      if (clause.body.length) result = joinStatements(result, formatStatementList(clause.body, indent + 1), "\n");
    });
    result += end;
  } else if (statementType == 'WhileStatement') {
    result = joinStatements('while', formatExpression(statement.condition, null, indent));
    result = joinStatements(result, 'do');
    if (statement.body.length != 0) {
      result = joinStatements(result, formatStatementList(statement.body, indent + 1), "\n");
      result = joinStatements(result, end);
    } else result = result + " end";
  } else if (statementType == 'DoStatement') {
    result = "do\n" + formatStatementList(statement.body, indent + 1);
    result = joinStatements(result, end);
  } else if (statementType == 'Chunk') {
    result = formatStatementList(statement.body, indent);
  } else if (statementType == 'ReturnStatement') {
    result = 'return';
    each(statement.arguments, function (argument, needsComma) {
      result = joinStatements(result, formatExpression(argument, null, indent));
      if (needsComma) result += ',';
    });
  } else if (statementType == 'BreakStatement') {
    result = 'break';
  } else if (statementType == "ContinueStatement") {
    result = "continue";
  } else if (statementType == "CompoundAssignmentStatement") {
    result = "".concat(formatExpression(statement.variable), " ").concat(statement.op, "= ").concat(formatExpression(statement.value));
  } else if (statementType == 'RepeatStatement') {
    result = joinStatements('repeat', formatStatementList(statement.body, indent + 1), "\n");
    result = joinStatements(result, 'until', newline);
    result = joinStatements(result, formatExpression(statement.condition, null, indent + 1));
  } else if (statementType == 'FunctionDeclaration') {
    result = (statement.isLocal ? 'local ' : '') + 'function ';
    result += formatExpression(statement.identifier, null, indent);
    result += '(';
    if (statement.parameters.length) {
      each(statement.parameters, function (parameter, needsComma) {
        result += parameter.name || parameter.value;
        if (needsComma) result += ', ';
      });
    }
    result += ')';
    result = joinStatements(result, formatStatementList(statement.body, indent + 1), "\n");
    result = joinStatements(result, end);
  } else if (statementType == 'ForGenericStatement') {
    result = 'for ';
    each(statement.variables, function (variable, needsComma) {
      result += variable.name;
      if (needsComma) result += ', ';
    });
    result += ' in';
    each(statement.iterators, function (iterator, needsComma) {
      result = joinStatements(result, formatExpression(iterator, null, indent));
      if (needsComma) result += ',';
    });
    result = joinStatements(result, "do");
    result = joinStatements(result, formatStatementList(statement.body, indent + 1), "\n");
    result = joinStatements(result, end);
  } else if (statementType == 'ForNumericStatement') {
    result = 'for ' + statement.variable.name + ' = ';
    result += formatExpression(statement.start, null, indent) + ', ' + formatExpression(statement.end, null, indent);
    if (statement.step && statement.step.value != 1) {
      result += ', ' + formatExpression(statement.step, null, indent);
    }
    result = joinStatements(result, 'do');
    result = joinStatements(result, formatStatementList(statement.body, indent + 1), "\n");
    result = joinStatements(result, end);
  } else if (statementType == 'LabelStatement') result = '::' + statement.label.name + '::';else if (statementType == "CommentStatement") return statement.raw ?? "-- " + statement.text;else if (statementType == 'GotoStatement') result = 'goto ' + statement.label.name;else throw TypeError('Unknown statement type: `' + statementType + '`');
  return result;
};
const beautify = (argument, opt) => {
  var ast = typeof argument == 'string' ? parse(argument) : argument;
  if (opt?.expr) return formatExpression(argument);
  if (opt) Object.assign(settings, opt);else Object.assign(settings, defaultSettings);
  return formatStatementList(Array.isArray(ast) ? ast : ast.body);
};
export default beautify;