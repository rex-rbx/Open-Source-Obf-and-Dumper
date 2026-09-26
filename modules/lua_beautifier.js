const luaparse = require('luaparse');
luaparse.defaultOptions.comments = false;
luaparse.defaultOptions.scope = true;
const parse = luaparse.parse;
let param_count = 0;
let var_id = 0;
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
const complex = ["TableConstructorExpression"];
const isComplex = stat => complex.includes(stat.type);
var each = function (array, fn) {
  var index = -1;
  var length = array.length;
  var max = length - 1;
  while (++index < length) {
    fn(array[index], index < max);
  }
};
var indexOf = function (array, value) {
  var index = -1;
  var length = array.length;
  while (++index < length) {
    if (array[index] == value) {
      return index;
    }
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
var generateZeroes = function (length) {
  var zero = '0';
  var result = '';
  if (length < 1) {
    return result;
  }
  if (length == 1) {
    return zero;
  }
  while (length) {
    if (length & 1) {
      result += zero;
    }
    if (length >>= 1) {
      zero += zero;
    }
  }
  return result;
};
function isKeyword(id) {
  switch (id.length) {
    case 2:
      return 'do' == id || 'if' == id || 'in' == id || 'or' == id;
    case 3:
      return 'and' == id || 'end' == id || 'for' == id || 'nil' == id || 'not' == id;
    case 4:
      return 'else' == id || 'goto' == id || 'then' == id || 'true' == id;
    case 5:
      return 'break' == id || 'false' == id || 'local' == id || 'until' == id || 'while' == id;
    case 6:
      return 'elseif' == id || 'repeat' == id || 'return' == id;
    case 8:
      return 'function' == id;
  }
  return false;
}
var identifierMap;
var identifiersInUse;
var generateIdentifier = function (originalName, isParam) {
  if (true) return originalName;
  if (isParam) {
    param_count++;
    const name = "p" + param_count;
    identifierMap[originalName] = name;
    return name;
  }
  if (originalName == 'self') return originalName;
  if (hasOwnProperty.call(identifierMap, originalName)) return identifierMap[originalName];
  var_id++;
  const currentIdentifier = "v" + var_id;
  identifierMap[originalName] = currentIdentifier;
  return currentIdentifier;
};
const joinStatements = (a, b, separator) => a + (separator || " ") + b;
const formatBase = function (base, indent = 0) {
  var result = '';
  var type = base.type;
  var needsParens = base.inParens;
  if (needsParens) {
    result += '(';
  }
  result += formatExpression(base, null, indent);
  if (needsParens) {
    result += ')';
  }
  return result;
};
var formatExpression = function (expression, options, indent = 0) {
  options = extend({
    'precedence': 0,
    'preserveIdentifiers': false
  }, options);
  var result = '';
  var currentPrecedence;
  var associativity;
  var operator;
  const tab = "    ".repeat(indent);
  const nextTab = "    ".repeat(indent + 1);
  const prevTab = indent <= 0 ? "" : "    ".repeat(indent - 1);
  const newline = "\n" + tab;
  const end = newline + "end";
  const prevEnd = "\n" + prevTab + "end";
  var expressionType = expression.type;
  if (expressionType == 'Identifier') {
    result = expression.isLocal && !options.preserveIdentifiers ? generateIdentifier(expression.name) : expression.name;
  } else if (expressionType == 'StringLiteral' || expressionType == 'NumericLiteral' || expressionType == 'BooleanLiteral' || expressionType == 'NilLiteral' || expressionType == 'VarargLiteral') {
    result = expression.raw;
  } else if (expressionType == 'LogicalExpression' || expressionType == 'BinaryExpression') {
    operator = expression.operator;
    currentPrecedence = PRECEDENCE[operator];
    associativity = 'left';
    result = formatExpression(expression.left, {
      'precedence': currentPrecedence,
      'direction': 'left',
      'parent': operator
    });
    result = joinStatements(result, operator);
    result = joinStatements(result, formatExpression(expression.right, {
      'precedence': currentPrecedence,
      'direction': 'right',
      'parent': operator
    }));
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
    result = formatBase(expression.base, indent + 1) + '(';
    const args = [];
    each(expression.arguments, function (argument) {
      args.push(formatExpression(argument, null, argument.type == "FunctionDeclaration" || argument.type == "CallExpression" ? indent + 1 : indent));
    });
    result += args.join(", ");
    result += ')';
  } else if (expressionType == 'TableCallExpression') {
    result = formatExpression(expression.base, null, indent + 1) + formatExpression(expression.arguments, null, indent);
  } else if (expressionType == 'StringCallExpression') {
    const argument = expression.base;
    result = formatExpression(argument, null, argument.type == "FunctionDeclaration" || argument.type == "CallExpression" ? indent + 1 : indent) + formatExpression(expression.argument, null, indent);
  } else if (expressionType == 'IndexExpression') {
    result = formatBase(expression.base) + '[' + formatExpression(expression.index, null, indent) + ']';
  } else if (expressionType == 'MemberExpression') {
    result = formatBase(expression.base) + expression.indexer + formatExpression(expression.identifier, {
      'preserveIdentifiers': true
    });
  } else if (expressionType == 'FunctionDeclaration') {
    result = 'function(';
    if (expression.parameters.length) {
      each(expression.parameters, function (parameter, needsComma) {
        result += parameter.name ? generateIdentifier(parameter.name, true) : parameter.value;
        if (needsComma) result += ', ';
      });
    }
    result += ')';
    result = joinStatements(result, formatStatementList(expression.body, indent), "\n");
    result = joinStatements(result, prevEnd);
  } else if (expressionType == 'TableConstructorExpression') {
    const stuff = [];
    each(expression.fields, function (field) {
      if (field.type == 'TableKey') {
        stuff.push('[' + formatExpression(field.key, null, indent) + '] = ' + formatExpression(field.value, null, indent + 1));
      } else if (field.type == 'TableValue') {
        stuff.push(formatExpression(field.value, null, indent + 1));
      } else {
        stuff.push(formatExpression(field.key, {
          'preserveIdentifiers': true
        }) + ' = ' + formatExpression(field.value, null, indent));
      }
    });
    const line = "\n" + nextTab;
    result = stuff.length == 0 ? "{}" : "{".concat(line).concat(stuff.join("," + line), "\n").concat(tab, "}");
  } else {
    throw TypeError('Unknown expression type: `' + expressionType + '`');
  }
  if (expression.inParens) return "(".concat(result, ")");
  return result;
};
var formatStatementList = function (body, indent = 0) {
  const stats = [];
  each(body, stat => stats.push(formatStatement(stat, indent)));
  const tab = "    ".repeat(indent);
  const joined = stats.join(";\n" + tab) + (stats.length > 0 ? ";" : "");
  return tab + joined;
};
var formatStatement = function (statement, indent = 0) {
  if (!statement) return '';
  var result = '';
  var statementType = statement.type;
  const tab = "    ".repeat(indent);
  const newline = "\n" + tab;
  const end = newline + "end";
  if (statementType == 'AssignmentStatement') {
    each(statement.variables, function (variable, needsComma) {
      result += formatExpression(variable, null, indent);
      if (needsComma) {
        result += ', ';
      }
    });
    result += ' = ';
    each(statement.init, function (init, needsComma) {
      result += formatExpression(init, null, indent);
      if (needsComma) {
        result += ',';
      }
    });
  } else if (statementType == 'LocalStatement') {
    result = 'local ';
    each(statement.variables, function (variable, needsComma) {
      result += generateIdentifier(variable.name);
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
    result = joinStatements(result, 'then');
    result = joinStatements(result, formatStatementList(statement.clauses[0].body, indent + 1), "\n");
    each(statement.clauses.slice(1), function (clause) {
      if (clause.condition) {
        result = joinStatements(result, 'elseif', newline);
        result = joinStatements(result, formatExpression(clause.condition), null, indent);
        result = joinStatements(result, 'then');
      } else {
        result = joinStatements(result, 'else', newline);
      }
      result = joinStatements(result, formatStatementList(clause.body, indent + 1), "\n");
    });
    result = joinStatements(result, end);
  } else if (statementType == 'WhileStatement') {
    result = joinStatements('while', formatExpression(statement.condition, null, indent));
    result = joinStatements(result, 'do');
    result = joinStatements(result, formatStatementList(statement.body, indent + 1), "\n");
    result = joinStatements(result, end);
  } else if (statementType == 'DoStatement') {
    result = "do\n" + formatStatementList(statement.body, indent + 1);
    result = joinStatements(result, end);
  } else if (statementType == 'ReturnStatement') {
    result = 'return';
    each(statement.arguments, function (argument, needsComma) {
      result = joinStatements(result, formatExpression(argument, null, indent));
      if (needsComma) result += ', ';
    });
  } else if (statementType == 'BreakStatement') {
    result = 'break';
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
        result += parameter.name ? generateIdentifier(parameter.name, true) : parameter.value;
        if (needsComma) result += ', ';
      });
    }
    result += ')';
    result = joinStatements(result, formatStatementList(statement.body, indent + 1), "\n");
    result = joinStatements(result, end);
  } else if (statementType == 'ForGenericStatement') {
    result = 'for ';
    each(statement.variables, function (variable, needsComma) {
      result += generateIdentifier(variable.name);
      if (needsComma) result += ', ';
    });
    result += ' in';
    each(statement.iterators, function (iterator, needsComma) {
      result = joinStatements(result, formatExpression(iterator, null, indent));
      if (needsComma) result += ', ';
    });
    result = joinStatements(result, "do");
    result = joinStatements(result, formatStatementList(statement.body, indent + 1), "\n");
    result = joinStatements(result, end);
  } else if (statementType == 'ForNumericStatement') {
    result = 'for ' + generateIdentifier(statement.variable.name) + ' = ';
    result += formatExpression(statement.start, null, indent) + ', ' + formatExpression(statement.end, null, indent);
    if (statement.step) {
      result += ', ' + formatExpression(statement.step, null, indent);
    }
    result = joinStatements(result, 'do');
    result = joinStatements(result, formatStatementList(statement.body, indent + 1), "\n");
    result = joinStatements(result, end);
  } else if (statementType == 'LabelStatement') {
    result = '::' + generateIdentifier(statement.label.name) + '::';
  } else if (statementType == 'GotoStatement') {
    result = 'goto ' + generateIdentifier(statement.label.name);
  } else {
    throw TypeError('Unknown statement type: `' + statementType + '`');
  }
  return result;
};
const beautify = argument => {
  var ast = typeof argument == 'string' ? parse(argument) : argument;
  identifierMap = {};
  identifiersInUse = [];
  if (ast.globals) each(ast.globals, function (object) {
    var name = object.name;
    identifierMap[name] = name;
    identifiersInUse.push(name);
  });else throw Error('Missing required AST property: `globals`');
  return formatStatementList(ast.body);
};
module.exports = beautify;