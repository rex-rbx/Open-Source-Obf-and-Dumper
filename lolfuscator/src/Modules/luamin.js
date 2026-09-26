;
(function (root) {
  var freeExports = typeof exports == 'object' && exports;
  var freeModule = typeof module == 'object' && module && module.exports == freeExports && module;
  var freeGlobal = typeof global == 'object' && global;
  if (freeGlobal.global === freeGlobal || freeGlobal.window === freeGlobal) {
    root = freeGlobal;
  }
  var luaparse = root.luaparse || require('luaparse');
  luaparse.defaultOptions.comments = false;
  luaparse.defaultOptions.scope = true;
  var parse = luaparse.parse;
  var regexAlphaUnderscore = /[a-zA-Z_]/;
  var regexAlphaNumUnderscore = /[a-zA-Z0-9_]/;
  var regexDigits = /[0-9]/;
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
  var IDENTIFIER_PARTS = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '_'];
  var IDENTIFIER_PARTS_MAX = IDENTIFIER_PARTS.length - 1;
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
        return 'continue' == id || 'function' == id;
    }
    return false;
  }
  var currentIdentifier;
  var identifierMap;
  var identifiersInUse;
  var reservedIdentifiers = {
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
  var nextIdentifier = function (id) {
    var chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_';
    var base = chars.length;
    var result = id.split('');
    var i = result.length - 1;
    while (i >= 0) {
      var idx = chars.indexOf(result[i]);
      if (idx === -1) idx = -1;
      idx++;
      if (idx < base) {
        result[i] = chars[idx];
        return result.join('');
      }
      result[i] = chars[0];
      i--;
    }
    return chars[0] + result.join('');
  };
  var generateIdentifier = function (originalName, context) {
    var key = context ? context + ':' + originalName : originalName;
    if (Object.prototype.hasOwnProperty.call(identifierMap, key)) {
      return identifierMap[key];
    }
    var name;
    do {
      currentIdentifier = nextIdentifier(currentIdentifier);
      name = currentIdentifier;
    } while (reservedIdentifiers[name] || identifiersInUse.indexOf(name) !== -1);
    identifierMap[key] = name;
    return name;
  };
  var joinStatements = function (a, b, separator) {
    separator || (separator = ' ');
    var lastCharA = a.slice(-1);
    var firstCharB = b.charAt(0);
    if (lastCharA == '' || firstCharB == '') {
      return a + b;
    }
    if (regexAlphaUnderscore.test(lastCharA)) {
      if (regexAlphaNumUnderscore.test(firstCharB)) {
        return a + separator + b;
      } else {
        return a + b;
      }
    }
    if (regexDigits.test(lastCharA)) {
      if (firstCharB == '(' || !(firstCharB == '.' || regexAlphaUnderscore.test(firstCharB))) {
        return a + b;
      } else {
        return a + separator + b;
      }
    }
    if (lastCharA == firstCharB && lastCharA == '-') {
      return a + separator + b;
    }
    return a + b;
  };
  var formatBase = function (base) {
    var result = '';
    var type = base.type;
    var needsParens = base.inParens && (type == 'BinaryExpression' || type == 'FunctionDeclaration' || type == 'TableConstructorExpression' || type == 'LogicalExpression' || type == 'StringLiteral' || type == 'NilLiteral');
    if (needsParens) {
      result += '(';
    }
    result += formatExpression(base);
    if (needsParens) {
      result += ')';
    }
    return result;
  };
  var formatExpression = function (expression, options) {
    options = extend({
      'precedence': 0,
      'preserveIdentifiers': false
    }, options);
    var result = '';
    var currentPrecedence;
    var associativity;
    var operator;
    var expressionType = expression.type;
    if (expressionType == 'Identifier') {
      result = expression.isLocal && !options.preserveIdentifiers ? generateIdentifier(expression.name, options.context) : expression.name;
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
      result = joinStatements(operator, formatExpression(expression.argument, {
        'precedence': currentPrecedence
      }));
      if (currentPrecedence < options.precedence && !(options.parent == '^' && options.direction == 'right')) {
        result = '(' + result + ')';
      }
    } else if (expressionType == 'CallExpression') {
      result = formatBase(expression.base) + '(';
      each(expression.arguments, function (argument, needsComma) {
        result += formatExpression(argument);
        if (needsComma) {
          result += ',';
        }
      });
      result += ')';
    } else if (expressionType == 'TableCallExpression') {
      result = formatExpression(expression.base) + formatExpression(expression.arguments);
    } else if (expressionType == 'StringCallExpression') {
      result = formatExpression(expression.base) + formatExpression(expression.argument);
    } else if (expressionType == 'IndexExpression') {
      result = formatBase(expression.base) + '[' + formatExpression(expression.index) + ']';
    } else if (expressionType == 'MemberExpression') {
      result = formatBase(expression.base) + expression.indexer + formatExpression(expression.identifier, {
        'preserveIdentifiers': !expression.identifier.isLocal,
        'context': expression.identifier.isLocal ? 'key' : undefined
      });
    } else if (expressionType == 'FunctionDeclaration') {
      result = 'function(';
      if (expression.parameters.length) {
        each(expression.parameters, function (parameter, needsComma) {
          result += parameter.name ? generateIdentifier(parameter.name) : parameter.value;
          if (needsComma) {
            result += ',';
          }
        });
      }
      result += ')';
      result = joinStatements(result, formatStatementList(expression.body));
      result = joinStatements(result, 'end');
    } else if (expressionType == 'TableConstructorExpression') {
      result = '{';
      each(expression.fields, function (field, needsComma) {
        if (field.type == 'TableKey') {
          result += '[' + formatExpression(field.key) + ']=' + formatExpression(field.value);
        } else if (field.type == 'TableValue') {
          result += formatExpression(field.value);
        } else {
          result += formatExpression(field.key, {
            'preserveIdentifiers': !field.key.isLocal,
            'context': field.key.isLocal ? 'key' : undefined
          }) + '=' + formatExpression(field.value);
        }
        if (needsComma) {
          result += ',';
        }
      });
      result += '}';
    } else {
      throw TypeError('Unknown expression type: `' + expressionType + '`');
    }
    if (expression.inParens) {
      result = '(' + result + ')';
    }
    return result;
  };
  var formatStatementList = function (body) {
    var result = '';
    each(body, function (statement) {
      result = joinStatements(result, formatStatement(statement), ';');
    });
    return result;
  };
  var formatStatement = function (statement) {
    var result = '';
    var statementType = statement.type;
    if (statementType == 'AssignmentStatement') {
      each(statement.variables, function (variable, needsComma) {
        result += formatExpression(variable);
        if (needsComma) {
          result += ',';
        }
      });
      result += '=';
      each(statement.init, function (init, needsComma) {
        result += formatExpression(init);
        if (needsComma) {
          result += ',';
        }
      });
    } else if (statementType == 'LocalStatement') {
      result = 'local ';
      each(statement.variables, function (variable, needsComma) {
        result += generateIdentifier(variable.name);
        if (needsComma) {
          result += ',';
        }
      });
      if (statement.init.length) {
        result += '=';
        each(statement.init, function (init, needsComma) {
          result += formatExpression(init);
          if (needsComma) {
            result += ',';
          }
        });
      }
    } else if (statementType == 'CallStatement') {
      result = formatExpression(statement.expression);
    } else if (statementType == 'IfStatement') {
      result = joinStatements('if', formatExpression(statement.clauses[0].condition));
      result = joinStatements(result, 'then');
      result = joinStatements(result, formatStatementList(statement.clauses[0].body));
      each(statement.clauses.slice(1), function (clause) {
        if (clause.condition) {
          result = joinStatements(result, 'elseif');
          result = joinStatements(result, formatExpression(clause.condition));
          result = joinStatements(result, 'then');
        } else {
          result = joinStatements(result, 'else');
        }
        result = joinStatements(result, formatStatementList(clause.body));
      });
      result = joinStatements(result, 'end');
    } else if (statementType == 'WhileStatement') {
      result = joinStatements('while', formatExpression(statement.condition));
      result = joinStatements(result, 'do');
      result = joinStatements(result, formatStatementList(statement.body));
      result = joinStatements(result, 'end');
    } else if (statementType == 'DoStatement') {
      result = joinStatements('do', formatStatementList(statement.body));
      result = joinStatements(result, 'end');
    } else if (statementType == 'ReturnStatement') {
      result = 'return';
      each(statement.arguments, function (argument, needsComma) {
        result = joinStatements(result, formatExpression(argument));
        if (needsComma) {
          result += ',';
        }
      });
    } else if (statementType == 'BreakStatement') {
      result = 'break';
    } else if (statementType == 'ContinueStatement') {
      result = 'continue';
    } else if (statementType == 'RepeatStatement') {
      result = joinStatements('repeat', formatStatementList(statement.body));
      result = joinStatements(result, 'until');
      result = joinStatements(result, formatExpression(statement.condition));
    } else if (statementType == 'FunctionDeclaration') {
      result = (statement.isLocal ? 'local ' : '') + 'function ';
      result += formatExpression(statement.identifier);
      result += '(';
      if (statement.parameters.length) {
        each(statement.parameters, function (parameter, needsComma) {
          result += parameter.name ? generateIdentifier(parameter.name) : parameter.value;
          if (needsComma) {
            result += ',';
          }
        });
      }
      result += ')';
      result = joinStatements(result, formatStatementList(statement.body));
      result = joinStatements(result, 'end');
    } else if (statementType == 'ForGenericStatement') {
      result = 'for ';
      each(statement.variables, function (variable, needsComma) {
        result += generateIdentifier(variable.name);
        if (needsComma) {
          result += ',';
        }
      });
      result += ' in';
      each(statement.iterators, function (iterator, needsComma) {
        result = joinStatements(result, formatExpression(iterator));
        if (needsComma) {
          result += ',';
        }
      });
      result = joinStatements(result, 'do');
      result = joinStatements(result, formatStatementList(statement.body));
      result = joinStatements(result, 'end');
    } else if (statementType == 'ForNumericStatement') {
      result = 'for ' + generateIdentifier(statement.variable.name) + '=';
      result += formatExpression(statement.start) + ',' + formatExpression(statement.end);
      if (statement.step) {
        result += ',' + formatExpression(statement.step);
      }
      result = joinStatements(result, 'do');
      result = joinStatements(result, formatStatementList(statement.body));
      result = joinStatements(result, 'end');
    } else if (statementType == 'LabelStatement') {
      result = '::' + generateIdentifier(statement.label.name) + '::';
    } else if (statementType == 'GotoStatement') {
      result = 'goto ' + generateIdentifier(statement.label.name);
    } else {
      throw TypeError('Unknown statement type: `' + statementType + '`');
    }
    return result;
  };
  var minify = function (argument) {
    var ast = typeof argument == 'string' ? parse(argument) : argument;
    identifierMap = {};
    identifiersInUse = [];
    currentIdentifier = '9';
    if (ast.globals) {
      each(ast.globals, function (object) {
        var name = object.name;
        identifierMap[name] = name;
        identifiersInUse.push(name);
      });
    } else {
      throw Error('Missing required AST property: `globals`');
    }
    return formatStatementList(ast.body);
  };
  var luamin = {
    'version': '1.0.4',
    'minify': minify
  };
  if (typeof define == 'function' && typeof define.amd == 'object' && define.amd) {
    define(function () {
      return luamin;
    });
  } else if (freeExports && !freeExports.nodeType) {
    if (freeModule) {
      freeModule.exports = luamin;
    } else {
      extend(freeExports, luamin);
    }
  } else {
    root.luamin = luamin;
  }
})(this);