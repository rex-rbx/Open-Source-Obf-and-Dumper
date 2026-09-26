(function (root, name, factory) {
  'use strict';
  var objectTypes = {
      'function': true,
      'object': true
    },
    freeExports = objectTypes[typeof exports] && exports && !exports.nodeType && exports,
    freeModule = objectTypes[typeof module] && module && !module.nodeType && module,
    freeGlobal = freeExports && freeModule && typeof global == 'object' && global,
    moduleExports = freeModule && freeModule.exports === freeExports && freeExports;
  if (freeGlobal && (freeGlobal.global === freeGlobal || freeGlobal.window === freeGlobal || freeGlobal.self === freeGlobal)) {
    root = freeGlobal;
  }
  if (typeof define == 'function' && typeof define.amd == 'object' && define.amd) {
    define(['exports'], factory);
    if (freeExports && moduleExports) factory(freeModule.exports);
  } else if (freeExports && freeModule) {
    if (moduleExports) factory(freeModule.exports);else factory(freeExports);
  } else {
    factory(root[name] = {});
  }
})(this, 'luaparse', function (exports) {
  'use strict';

  exports.version = '0.2.1';
  var input, options, length;
  var defaultOptions = exports.defaultOptions = {
    wait: false,
    comments: true,
    scope: false,
    locations: false,
    ranges: false,
    onCreateNode: null,
    onCreateScope: null,
    onDestroyScope: null
  };
  var EOF = 1,
    StringLiteral = 2,
    Keyword = 4,
    Identifier = 8,
    NumericLiteral = 16,
    Punctuator = 32,
    BooleanLiteral = 64,
    NilLiteral = 128,
    VarargLiteral = 256;
  exports.tokenTypes = {
    EOF: EOF,
    StringLiteral: StringLiteral,
    Keyword: Keyword,
    Identifier: Identifier,
    NumericLiteral: NumericLiteral,
    Punctuator: Punctuator,
    BooleanLiteral: BooleanLiteral,
    NilLiteral: NilLiteral,
    VarargLiteral: VarargLiteral
  };
  var errors = exports.errors = {
    unexpected: 'unexpected %1 \'%2\' near \'%3\'',
    expected: '\'%1\' expected near \'%2\'',
    expectedToken: '%1 expected near \'%2\'',
    unfinishedString: 'unfinished string near \'%1\'',
    malformedNumber: 'malformed number near \'%1\'',
    invalidVar: 'invalid left-hand side of assignment near \'%1\''
  };
  var ast = exports.ast = {
    labelStatement: function (label) {
      return {
        type: 'LabelStatement',
        label: label
      };
    },
    breakStatement: function () {
      return {
        type: 'BreakStatement'
      };
    },
    continueStatement: function () {
      return {
        type: 'ContinueStatement'
      };
    },
    gotoStatement: function (label) {
      return {
        type: 'GotoStatement',
        label: label
      };
    },
    returnStatement: function (args) {
      return {
        type: 'ReturnStatement',
        'arguments': args
      };
    },
    ifStatement: function (clauses) {
      return {
        type: 'IfStatement',
        clauses: clauses
      };
    },
    ifClause: function (condition, body) {
      return {
        type: 'IfClause',
        condition: condition,
        body: body
      };
    },
    elseifClause: function (condition, body) {
      return {
        type: 'ElseifClause',
        condition: condition,
        body: body
      };
    },
    elseClause: function (body) {
      return {
        type: 'ElseClause',
        body: body
      };
    },
    whileStatement: function (condition, body) {
      return {
        type: 'WhileStatement',
        condition: condition,
        body: body
      };
    },
    doStatement: function (body) {
      return {
        type: 'DoStatement',
        body: body
      };
    },
    repeatStatement: function (condition, body) {
      return {
        type: 'RepeatStatement',
        condition: condition,
        body: body
      };
    },
    localStatement: function (variables, init) {
      return {
        type: 'LocalStatement',
        variables: variables,
        init: init
      };
    },
    assignmentStatement: function (variables, init) {
      return {
        type: 'AssignmentStatement',
        variables: variables,
        init: init
      };
    },
    callStatement: function (expression) {
      return {
        type: 'CallStatement',
        expression: expression
      };
    },
    functionStatement: function (identifier, parameters, isLocal, body) {
      return {
        type: 'FunctionDeclaration',
        identifier: identifier,
        isLocal: isLocal,
        parameters: parameters,
        body: body
      };
    },
    forNumericStatement: function (variable, start, end, step, body) {
      return {
        type: 'ForNumericStatement',
        variable: variable,
        start: start,
        end: end,
        step: step,
        body: body
      };
    },
    forGenericStatement: function (variables, iterators, body) {
      return {
        type: 'ForGenericStatement',
        variables: variables,
        iterators: iterators,
        body: body
      };
    },
    chunk: function (body) {
      return {
        type: 'Chunk',
        body: body
      };
    },
    identifier: function (name) {
      return {
        type: 'Identifier',
        name: name
      };
    },
    literal: function (type, value, raw) {
      type = type === StringLiteral ? 'StringLiteral' : type === NumericLiteral ? 'NumericLiteral' : type === BooleanLiteral ? 'BooleanLiteral' : type === NilLiteral ? 'NilLiteral' : 'VarargLiteral';
      return {
        type: type,
        value: value,
        raw: raw
      };
    },
    tableKey: function (key, value) {
      return {
        type: 'TableKey',
        key: key,
        value: value
      };
    },
    tableKeyString: function (key, value) {
      return {
        type: 'TableKeyString',
        key: key,
        value: value
      };
    },
    tableValue: function (value) {
      return {
        type: 'TableValue',
        value: value
      };
    },
    tableConstructorExpression: function (fields) {
      return {
        type: 'TableConstructorExpression',
        fields: fields
      };
    },
    binaryExpression: function (operator, left, right) {
      var type = 'and' === operator || 'or' === operator ? 'LogicalExpression' : 'BinaryExpression';
      return {
        type: type,
        operator: operator,
        left: left,
        right: right
      };
    },
    unaryExpression: function (operator, argument) {
      return {
        type: 'UnaryExpression',
        operator: operator,
        argument: argument
      };
    },
    memberExpression: function (base, indexer, identifier) {
      return {
        type: 'MemberExpression',
        indexer: indexer,
        identifier: identifier,
        base: base
      };
    },
    indexExpression: function (base, index) {
      return {
        type: 'IndexExpression',
        base: base,
        index: index
      };
    },
    callExpression: function (base, args) {
      return {
        type: 'CallExpression',
        base: base,
        'arguments': args
      };
    },
    tableCallExpression: function (base, args) {
      return {
        type: 'TableCallExpression',
        base: base,
        'arguments': args
      };
    },
    stringCallExpression: function (base, argument) {
      return {
        type: 'StringCallExpression',
        base: base,
        argument: argument
      };
    },
    comment: function (value, raw) {
      return {
        type: 'Comment',
        value: value,
        raw: raw
      };
    }
  };
  function finishNode(node) {
    if (trackLocations) {
      var location = locations.pop();
      location.complete();
      if (options.locations) node.loc = location.loc;
      if (options.ranges) node.range = location.range;
    }
    if (options.onCreateNode) options.onCreateNode(node);
    return node;
  }
  var slice = Array.prototype.slice,
    toString = Object.prototype.toString,
    indexOf = function indexOf(array, element) {
      for (var i = 0, length = array.length; i < length; i++) {
        if (array[i] === element) return i;
      }
      return -1;
    };
  function indexOfObject(array, property, element) {
    for (var i = 0, length = array.length; i < length; i++) {
      if (array[i][property] === element) return i;
    }
    return -1;
  }
  function sprintf(format) {
    var args = slice.call(arguments, 1);
    format = format.replace(/%(\d)/g, function (match, index) {
      return '' + args[index - 1] || '';
    });
    return format;
  }
  function extend() {
    var args = slice.call(arguments),
      dest = {},
      src,
      prop;
    for (var i = 0, length = args.length; i < length; i++) {
      src = args[i];
      for (prop in src) if (src.hasOwnProperty(prop)) {
        dest[prop] = src[prop];
      }
    }
    return dest;
  }
  function raise(token) {
    var message = sprintf.apply(null, slice.call(arguments, 1)),
      error,
      col;
    if ('undefined' !== typeof token.line) {
      col = token.range[0] - token.lineStart;
      error = new SyntaxError(sprintf('[%1:%2] %3', token.line, col, message));
      error.line = token.line;
      error.index = token.range[0];
      error.column = col;
    } else {
      col = index - lineStart + 1;
      error = new SyntaxError(sprintf('[%1:%2] %3', line, col, message));
      error.index = index;
      error.line = line;
      error.column = col;
    }
    throw error;
  }
  function raiseUnexpectedToken(type, token) {
    raise(token, errors.expectedToken, type, token.value);
  }
  function unexpected(found, near) {
    if ('undefined' === typeof near) near = lookahead.value;
    if ('undefined' !== typeof found.type) {
      var type;
      switch (found.type) {
        case StringLiteral:
          type = 'string';
          break;
        case Keyword:
          type = 'keyword';
          break;
        case Identifier:
          type = 'identifier';
          break;
        case NumericLiteral:
          type = 'number';
          break;
        case Punctuator:
          type = 'symbol';
          break;
        case BooleanLiteral:
          type = 'boolean';
          break;
        case NilLiteral:
          return raise(found, errors.unexpected, 'symbol', 'nil', near);
      }
      return raise(found, errors.unexpected, type, found.value, near);
    }
    return raise(found, errors.unexpected, 'symbol', found, near);
  }
  var index, token, previousToken, lookahead, comments, tokenStart, line, lineStart;
  exports.lex = lex;
  function lex() {
    skipWhiteSpace();
    while (45 === input.charCodeAt(index) && 45 === input.charCodeAt(index + 1)) {
      scanComment();
      skipWhiteSpace();
    }
    if (index >= length) return {
      type: EOF,
      value: '<eof>',
      line: line,
      lineStart: lineStart,
      range: [index, index]
    };
    var charCode = input.charCodeAt(index),
      next = input.charCodeAt(index + 1);
    tokenStart = index;
    if (isIdentifierStart(charCode)) return scanIdentifierOrKeyword();
    switch (charCode) {
      case 39:
      case 34:
        return scanStringLiteral();
      case 48:
      case 49:
      case 50:
      case 51:
      case 52:
      case 53:
      case 54:
      case 55:
      case 56:
      case 57:
        return scanNumericLiteral();
      case 46:
        if (isDecDigit(next)) return scanNumericLiteral();
        if (46 === next) {
          if (61 === input.charCodeAt(index + 2)) return scanPunctuator('..=');
          if (46 === input.charCodeAt(index + 2)) return scanVarargLiteral();
          return scanPunctuator('..');
        }
        return scanPunctuator('.');
      case 61:
        if (61 === next) return scanPunctuator('==');
        return scanPunctuator('=');
      case 62:
        if (61 === next) return scanPunctuator('>=');
        if (62 === next) return scanPunctuator('>>');
        return scanPunctuator('>');
      case 60:
        if (60 === next) return scanPunctuator('<<');
        if (61 === next) return scanPunctuator('<=');
        return scanPunctuator('<');
      case 126:
        if (61 === next) return scanPunctuator('~=');
        return scanPunctuator('~');
      case 58:
        if (58 === next) return scanPunctuator('::');
        return scanPunctuator(':');
      case 91:
        if (91 === next || 61 === next) return scanLongStringLiteral();
        return scanPunctuator('[');
      case 47:
        if (47 === next) return scanPunctuator('//');
        if (61 === next) return scanPunctuator('/=');
        return scanPunctuator('/');
      case 42:
      case 94:
      case 37:
        if (61 === next) return scanPunctuator(input.charAt(index) + '=');
        return scanPunctuator(input.charAt(index));
      case 43:
        if (61 === next) return scanPunctuator('+=');
        return scanPunctuator('+');
      case 45:
        if (61 === next) return scanPunctuator('-=');
        return scanPunctuator('-');
      case 44:
      case 123:
      case 124:
      case 125:
      case 93:
      case 40:
      case 41:
      case 59:
      case 38:
      case 35:
        return scanPunctuator(input.charAt(index));
    }
    return unexpected(input.charAt(index));
  }
  function consumeEOL() {
    var charCode = input.charCodeAt(index),
      peekCharCode = input.charCodeAt(index + 1);
    if (isLineTerminator(charCode)) {
      if (10 === charCode && 13 === peekCharCode) index++;
      if (13 === charCode && 10 === peekCharCode) index++;
      line++;
      lineStart = ++index;
      return true;
    }
    return false;
  }
  function skipWhiteSpace() {
    while (index < length) {
      var charCode = input.charCodeAt(index);
      if (isWhiteSpace(charCode)) {
        index++;
      } else if (!consumeEOL()) {
        break;
      }
    }
  }
  function scanIdentifierOrKeyword() {
    var value, type;
    while (isIdentifierPart(input.charCodeAt(++index)));
    value = input.slice(tokenStart, index);
    if (isKeyword(value)) {
      type = Keyword;
    } else if ('true' === value || 'false' === value) {
      type = BooleanLiteral;
      value = 'true' === value;
    } else if ('nil' === value) {
      type = NilLiteral;
      value = null;
    } else {
      type = Identifier;
    }
    return {
      type: type,
      value: value,
      line: line,
      lineStart: lineStart,
      range: [tokenStart, index]
    };
  }
  function scanPunctuator(value) {
    index += value.length;
    return {
      type: Punctuator,
      value: value,
      line: line,
      lineStart: lineStart,
      range: [tokenStart, index]
    };
  }
  function scanVarargLiteral() {
    index += 3;
    return {
      type: VarargLiteral,
      value: '...',
      line: line,
      lineStart: lineStart,
      range: [tokenStart, index]
    };
  }
  function scanStringLiteral() {
    var delimiter = input.charCodeAt(index++),
      stringStart = index,
      string = '',
      charCode;
    while (index < length) {
      charCode = input.charCodeAt(index++);
      if (delimiter === charCode) break;
      if (92 === charCode) {
        string += input.slice(stringStart, index - 1) + readEscapeSequence();
        stringStart = index;
      } else if (index >= length || isLineTerminator(charCode)) {
        string += input.slice(stringStart, index - 1);
        raise({}, errors.unfinishedString, string + String.fromCharCode(charCode));
      }
    }
    string += input.slice(stringStart, index - 1);
    return {
      type: StringLiteral,
      value: string,
      line: line,
      lineStart: lineStart,
      range: [tokenStart, index]
    };
  }
  function scanLongStringLiteral() {
    var string = readLongString();
    if (false === string) raise(token, errors.expected, '[', token.value);
    return {
      type: StringLiteral,
      value: string,
      line: line,
      lineStart: lineStart,
      range: [tokenStart, index]
    };
  }
  function scanNumericLiteral() {
    var character = input.charAt(index),
      next = input.charAt(index + 1);
    var value = '0' === character && 'xX'.indexOf(next || null) >= 0 ? readHexLiteral() : readDecLiteral();
    return {
      type: NumericLiteral,
      value: value,
      line: line,
      lineStart: lineStart,
      range: [tokenStart, index]
    };
  }
  function readHexLiteral() {
    var fraction = 0,
      binaryExponent = 1,
      binarySign = 1,
      digit,
      fractionStart,
      exponentStart,
      digitStart;
    digitStart = index += 2;
    if (!isHexDigit(input.charCodeAt(index))) raise({}, errors.malformedNumber, input.slice(tokenStart, index));
    while (isHexDigit(input.charCodeAt(index))) index++;
    digit = parseInt(input.slice(digitStart, index), 16);
    if ('.' === input.charAt(index)) {
      fractionStart = ++index;
      while (isHexDigit(input.charCodeAt(index))) index++;
      fraction = input.slice(fractionStart, index);
      fraction = fractionStart === index ? 0 : parseInt(fraction, 16) / Math.pow(16, index - fractionStart);
    }
    if ('pP'.indexOf(input.charAt(index) || null) >= 0) {
      index++;
      if ('+-'.indexOf(input.charAt(index) || null) >= 0) binarySign = '+' === input.charAt(index++) ? 1 : -1;
      exponentStart = index;
      if (!isDecDigit(input.charCodeAt(index))) raise({}, errors.malformedNumber, input.slice(tokenStart, index));
      while (isDecDigit(input.charCodeAt(index))) index++;
      binaryExponent = input.slice(exponentStart, index);
      binaryExponent = Math.pow(2, binaryExponent * binarySign);
    }
    return (digit + fraction) * binaryExponent;
  }
  function readDecLiteral() {
    while (isDecDigit(input.charCodeAt(index))) index++;
    if ('.' === input.charAt(index)) {
      index++;
      while (isDecDigit(input.charCodeAt(index))) index++;
    }
    if ('eE'.indexOf(input.charAt(index) || null) >= 0) {
      index++;
      if ('+-'.indexOf(input.charAt(index) || null) >= 0) index++;
      if (!isDecDigit(input.charCodeAt(index))) raise({}, errors.malformedNumber, input.slice(tokenStart, index));
      while (isDecDigit(input.charCodeAt(index))) index++;
    }
    return parseFloat(input.slice(tokenStart, index));
  }
  function readEscapeSequence() {
    var sequenceStart = index;
    switch (input.charAt(index)) {
      case 'n':
        index++;
        return '\n';
      case 'r':
        index++;
        return '\r';
      case 't':
        index++;
        return '\t';
      case 'v':
        index++;
        return '\x0B';
      case 'b':
        index++;
        return '\b';
      case 'f':
        index++;
        return '\f';
      case 'z':
        index++;
        skipWhiteSpace();
        return '';
      case 'x':
        if (isHexDigit(input.charCodeAt(index + 1)) && isHexDigit(input.charCodeAt(index + 2))) {
          index += 3;
          return '\\' + input.slice(sequenceStart, index);
        }
        return '\\' + input.charAt(index++);
      default:
        if (isDecDigit(input.charCodeAt(index))) {
          while (isDecDigit(input.charCodeAt(++index)));
          return '\\' + input.slice(sequenceStart, index);
        }
        return input.charAt(index++);
    }
  }
  function scanComment() {
    tokenStart = index;
    index += 2;
    var character = input.charAt(index),
      content = '',
      isLong = false,
      commentStart = index,
      lineStartComment = lineStart,
      lineComment = line;
    if ('[' === character) {
      content = readLongString();
      if (false === content) content = character;else isLong = true;
    }
    if (!isLong) {
      while (index < length) {
        if (isLineTerminator(input.charCodeAt(index))) break;
        index++;
      }
      if (options.comments) content = input.slice(commentStart, index);
    }
    if (options.comments) {
      var node = ast.comment(content, input.slice(tokenStart, index));
      if (options.locations) {
        node.loc = {
          start: {
            line: lineComment,
            column: tokenStart - lineStartComment
          },
          end: {
            line: line,
            column: index - lineStart
          }
        };
      }
      if (options.ranges) {
        node.range = [tokenStart, index];
      }
      if (options.onCreateNode) options.onCreateNode(node);
      comments.push(node);
    }
  }
  function readLongString() {
    var level = 0,
      content = '',
      terminator = false,
      character,
      stringStart;
    index++;
    while ('=' === input.charAt(index + level)) level++;
    if ('[' !== input.charAt(index + level)) return false;
    index += level + 1;
    if (isLineTerminator(input.charCodeAt(index))) consumeEOL();
    stringStart = index;
    while (index < length) {
      if (isLineTerminator(input.charCodeAt(index))) consumeEOL();
      character = input.charAt(index++);
      if (']' === character) {
        terminator = true;
        for (var i = 0; i < level; i++) {
          if ('=' !== input.charAt(index + i)) terminator = false;
        }
        if (']' !== input.charAt(index + level)) terminator = false;
      }
      if (terminator) break;
    }
    content += input.slice(stringStart, index - 1);
    index += level + 1;
    return content;
  }
  function next() {
    previousToken = token;
    token = lookahead;
    lookahead = lex();
  }
  function consume(value) {
    if (value === token.value) {
      next();
      return true;
    }
    return false;
  }
  function expect(value) {
    if (value === token.value) next();else raise(token, errors.expected, value, token.value);
  }
  function isWhiteSpace(charCode) {
    return 9 === charCode || 32 === charCode || 0xB === charCode || 0xC === charCode;
  }
  function isLineTerminator(charCode) {
    return 10 === charCode || 13 === charCode;
  }
  function isDecDigit(charCode) {
    return charCode >= 48 && charCode <= 57;
  }
  function isHexDigit(charCode) {
    return charCode >= 48 && charCode <= 57 || charCode >= 97 && charCode <= 102 || charCode >= 65 && charCode <= 70;
  }
  function isIdentifierStart(charCode) {
    return charCode >= 65 && charCode <= 90 || charCode >= 97 && charCode <= 122 || 95 === charCode;
  }
  function isIdentifierPart(charCode) {
    return charCode >= 65 && charCode <= 90 || charCode >= 97 && charCode <= 122 || 95 === charCode || charCode >= 48 && charCode <= 57;
  }
  function isKeyword(id) {
    switch (id.length) {
      case 2:
        return 'do' === id || 'if' === id || 'in' === id || 'or' === id;
      case 3:
        return 'and' === id || 'end' === id || 'for' === id || 'not' === id;
      case 4:
        return 'else' === id || 'goto' === id || 'then' === id;
      case 5:
        return 'break' === id || 'local' === id || 'until' === id || 'while' === id;
      case 6:
        return 'elseif' === id || 'repeat' === id || 'return' === id;
      case 8:
        return 'continue' === id || 'function' === id;
    }
    return false;
  }
  function isUnary(token) {
    if (Punctuator === token.type) return '#-~'.indexOf(token.value) >= 0;
    if (Keyword === token.type) return 'not' === token.value;
    return false;
  }
  function isCallExpression(expression) {
    switch (expression.type) {
      case 'CallExpression':
      case 'TableCallExpression':
      case 'StringCallExpression':
        return true;
    }
    return false;
  }
  function isBlockFollow(token) {
    if (EOF === token.type) return true;
    if (Keyword !== token.type) return false;
    switch (token.value) {
      case 'else':
      case 'elseif':
      case 'end':
      case 'until':
        return true;
      default:
        return false;
    }
  }
  var scopes, scopeDepth, globals;
  function createScope() {
    var scope = Array.apply(null, scopes[scopeDepth++]);
    scopes.push(scope);
    if (options.onCreateScope) options.onCreateScope();
  }
  function destroyScope() {
    var scope = scopes.pop();
    scopeDepth--;
    if (options.onDestroyScope) options.onDestroyScope();
  }
  function scopeIdentifierName(name) {
    if (-1 !== indexOf(scopes[scopeDepth], name)) return;
    scopes[scopeDepth].push(name);
  }
  function scopeIdentifier(node) {
    scopeIdentifierName(node.name);
    attachScope(node, true);
  }
  function attachScope(node, isLocal) {
    if (!isLocal && -1 === indexOfObject(globals, 'name', node.name)) globals.push(node);
    node.isLocal = isLocal;
  }
  function scopeHasName(name) {
    return -1 !== indexOf(scopes[scopeDepth], name);
  }
  var locations = [],
    trackLocations;
  function createLocationMarker() {
    return new Marker(token);
  }
  function Marker(token) {
    if (options.locations) {
      this.loc = {
        start: {
          line: token.line,
          column: token.range[0] - token.lineStart
        },
        end: {
          line: 0,
          column: 0
        }
      };
    }
    if (options.ranges) this.range = [token.range[0], 0];
  }
  Marker.prototype.complete = function () {
    if (options.locations) {
      this.loc.end.line = previousToken.line;
      this.loc.end.column = previousToken.range[1] - previousToken.lineStart;
    }
    if (options.ranges) {
      this.range[1] = previousToken.range[1];
    }
  };
  function markLocation() {
    if (trackLocations) locations.push(createLocationMarker());
  }
  function pushLocation(marker) {
    if (trackLocations) locations.push(marker);
  }
  function parseChunk() {
    next();
    markLocation();
    if (options.scope) createScope();
    var body = parseBlock();
    if (options.scope) destroyScope();
    if (EOF !== token.type) unexpected(token);
    if (trackLocations && !body.length) previousToken = token;
    return finishNode(ast.chunk(body));
  }
  function parseBlock(terminator) {
    var block = [],
      statement;
    while (!isBlockFollow(token)) {
      if ('return' === token.value) {
        block.push(parseStatement());
        break;
      }
      statement = parseStatement();
      if (statement) block.push(statement);
    }
    return block;
  }
  function parseStatement() {
    markLocation();
    if (Keyword === token.type) {
      switch (token.value) {
        case 'local':
          next();
          return parseLocalStatement();
        case 'if':
          next();
          return parseIfStatement();
        case 'return':
          next();
          return parseReturnStatement();
        case 'function':
          next();
          var name = parseFunctionName();
          return parseFunctionDeclaration(name);
        case 'while':
          next();
          return parseWhileStatement();
        case 'for':
          next();
          return parseForStatement();
        case 'repeat':
          next();
          return parseRepeatStatement();
        case 'break':
          next();
          return parseBreakStatement();
        case 'continue':
          next();
          return parseContinueStatement();
        case 'do':
          next();
          return parseDoStatement();
        case 'goto':
          next();
          return parseGotoStatement();
      }
    }
    if (Punctuator === token.type) {
      if (consume('::')) return parseLabelStatement();
    }
    if (trackLocations) locations.pop();
    if (consume(';')) return;
    return parseAssignmentOrCallStatement();
  }
  function parseLabelStatement() {
    var name = token.value,
      label = parseIdentifier();
    if (options.scope) {
      scopeIdentifierName('::' + name + '::');
      attachScope(label, true);
    }
    expect('::');
    return finishNode(ast.labelStatement(label));
  }
  function parseBreakStatement() {
    return finishNode(ast.breakStatement());
  }
  function parseContinueStatement() {
    return finishNode(ast.continueStatement());
  }
  function parseGotoStatement() {
    var name = token.value,
      label = parseIdentifier();
    return finishNode(ast.gotoStatement(label));
  }
  function parseDoStatement() {
    if (options.scope) createScope();
    var body = parseBlock();
    if (options.scope) destroyScope();
    expect('end');
    return finishNode(ast.doStatement(body));
  }
  function parseWhileStatement() {
    var condition = parseExpectedExpression();
    expect('do');
    if (options.scope) createScope();
    var body = parseBlock();
    if (options.scope) destroyScope();
    expect('end');
    return finishNode(ast.whileStatement(condition, body));
  }
  function parseRepeatStatement() {
    if (options.scope) createScope();
    var body = parseBlock();
    expect('until');
    var condition = parseExpectedExpression();
    if (options.scope) destroyScope();
    return finishNode(ast.repeatStatement(condition, body));
  }
  function parseReturnStatement() {
    var expressions = [];
    if ('end' !== token.value) {
      var expression = parseExpression();
      if (null != expression) expressions.push(expression);
      while (consume(',')) {
        expression = parseExpectedExpression();
        expressions.push(expression);
      }
      consume(';');
    }
    return finishNode(ast.returnStatement(expressions));
  }
  function parseIfStatement() {
    var clauses = [],
      condition,
      body,
      marker;
    if (trackLocations) {
      marker = locations[locations.length - 1];
      locations.push(marker);
    }
    condition = parseExpectedExpression();
    expect('then');
    if (options.scope) createScope();
    body = parseBlock();
    if (options.scope) destroyScope();
    clauses.push(finishNode(ast.ifClause(condition, body)));
    if (trackLocations) marker = createLocationMarker();
    while (consume('elseif')) {
      pushLocation(marker);
      condition = parseExpectedExpression();
      expect('then');
      if (options.scope) createScope();
      body = parseBlock();
      if (options.scope) destroyScope();
      clauses.push(finishNode(ast.elseifClause(condition, body)));
      if (trackLocations) marker = createLocationMarker();
    }
    if (consume('else')) {
      if (trackLocations) {
        marker = new Marker(previousToken);
        locations.push(marker);
      }
      if (options.scope) createScope();
      body = parseBlock();
      if (options.scope) destroyScope();
      clauses.push(finishNode(ast.elseClause(body)));
    }
    expect('end');
    return finishNode(ast.ifStatement(clauses));
  }
  function parseForStatement() {
    var variable = parseIdentifier(),
      body;
    if (options.scope) {
      createScope();
      scopeIdentifier(variable);
    }
    if (consume('=')) {
      var start = parseExpectedExpression();
      expect(',');
      var end = parseExpectedExpression();
      var step = consume(',') ? parseExpectedExpression() : null;
      expect('do');
      body = parseBlock();
      expect('end');
      if (options.scope) destroyScope();
      return finishNode(ast.forNumericStatement(variable, start, end, step, body));
    } else {
      var variables = [variable];
      while (consume(',')) {
        variable = parseIdentifier();
        if (options.scope) scopeIdentifier(variable);
        variables.push(variable);
      }
      expect('in');
      var iterators = [];
      do {
        var expression = parseExpectedExpression();
        iterators.push(expression);
      } while (consume(','));
      expect('do');
      body = parseBlock();
      expect('end');
      if (options.scope) destroyScope();
      return finishNode(ast.forGenericStatement(variables, iterators, body));
    }
  }
  function parseLocalStatement() {
    var name;
    if (Identifier === token.type) {
      var variables = [],
        init = [];
      do {
        name = parseIdentifier();
        variables.push(name);
      } while (consume(','));
      if (consume('=')) {
        do {
          var expression = parseExpectedExpression();
          init.push(expression);
        } while (consume(','));
      }
      if (options.scope) {
        for (var i = 0, l = variables.length; i < l; i++) {
          scopeIdentifier(variables[i]);
        }
      }
      return finishNode(ast.localStatement(variables, init));
    }
    if (consume('function')) {
      name = parseIdentifier();
      if (options.scope) {
        scopeIdentifier(name);
        createScope();
      }
      return parseFunctionDeclaration(name, true);
    } else {
      raiseUnexpectedToken('<name>', token);
    }
  }
  function validateVar(node) {
    if (node.inParens || ['Identifier', 'MemberExpression', 'IndexExpression'].indexOf(node.type) === -1) {
      raise(token, errors.invalidVar, token.value);
    }
  }
  function parseAssignmentOrCallStatement() {
    var previous = token,
      expression,
      marker;
    if (trackLocations) marker = createLocationMarker();
    expression = parsePrefixExpression();
    if (null == expression) return unexpected(token);
    if (',='.indexOf(token.value) >= 0) {
      var variables = [expression],
        init = [],
        exp;
      validateVar(expression);
      while (consume(',')) {
        exp = parsePrefixExpression();
        if (null == exp) raiseUnexpectedToken('<expression>', token);
        validateVar(exp);
        variables.push(exp);
      }
      expect('=');
      do {
        exp = parseExpectedExpression();
        init.push(exp);
      } while (consume(','));
      pushLocation(marker);
      return finishNode(ast.assignmentStatement(variables, init));
    }
    var compoundOps = {
      '+=': '+',
      '-=': '-',
      '*=': '*',
      '/=': '/',
      '^=': '^',
      '%=': '%',
      '..=': '..'
    };
    var compoundOp = compoundOps[token.value];
    if (compoundOp) {
      validateVar(expression);
      var lhs = expression;
      next();
      var rhs = parseExpectedExpression();
      var binExpr = {
        type: 'BinaryExpression',
        operator: compoundOp,
        left: lhs,
        right: rhs,
        inParens: false
      };
      pushLocation(marker);
      return finishNode(ast.assignmentStatement([lhs], [binExpr]));
    }
    if (isCallExpression(expression)) {
      pushLocation(marker);
      return finishNode(ast.callStatement(expression));
    }
    return unexpected(previous);
  }
  function parseIdentifier() {
    markLocation();
    var identifier = token.value;
    if (Identifier !== token.type) raiseUnexpectedToken('<name>', token);
    next();
    return finishNode(ast.identifier(identifier));
  }
  function parseFunctionDeclaration(name, isLocal) {
    var parameters = [];
    expect('(');
    if (!consume(')')) {
      while (true) {
        if (Identifier === token.type) {
          var parameter = parseIdentifier();
          if (options.scope) scopeIdentifier(parameter);
          parameters.push(parameter);
          if (consume(',')) continue;else if (consume(')')) break;
        } else if (VarargLiteral === token.type) {
          parameters.push(parsePrimaryExpression());
          expect(')');
          break;
        } else {
          raiseUnexpectedToken('<name> or \'...\'', token);
        }
      }
    }
    var body = parseBlock();
    expect('end');
    if (options.scope) destroyScope();
    isLocal = isLocal || false;
    return finishNode(ast.functionStatement(name, parameters, isLocal, body));
  }
  function parseFunctionName() {
    var base, name, marker;
    if (trackLocations) marker = createLocationMarker();
    base = parseIdentifier();
    if (options.scope) {
      attachScope(base, scopeHasName(base.name));
      createScope();
    }
    while (consume('.')) {
      pushLocation(marker);
      name = parseIdentifier();
      base = finishNode(ast.memberExpression(base, '.', name));
    }
    if (consume(':')) {
      pushLocation(marker);
      name = parseIdentifier();
      base = finishNode(ast.memberExpression(base, ':', name));
      if (options.scope) scopeIdentifierName('self');
    }
    return base;
  }
  function parseTableConstructor() {
    var fields = [],
      key,
      value;
    while (true) {
      markLocation();
      if (Punctuator === token.type && consume('[')) {
        key = parseExpectedExpression();
        expect(']');
        expect('=');
        value = parseExpectedExpression();
        fields.push(finishNode(ast.tableKey(key, value)));
      } else if (Identifier === token.type) {
        if ('=' === lookahead.value) {
          key = parseIdentifier();
          next();
          value = parseExpectedExpression();
          fields.push(finishNode(ast.tableKeyString(key, value)));
        } else {
          value = parseExpectedExpression();
          fields.push(finishNode(ast.tableValue(value)));
        }
      } else {
        if (null == (value = parseExpression())) {
          locations.pop();
          break;
        }
        fields.push(finishNode(ast.tableValue(value)));
      }
      if (',;'.indexOf(token.value) >= 0) {
        next();
        continue;
      }
      break;
    }
    expect('}');
    return finishNode(ast.tableConstructorExpression(fields));
  }
  function parseExpression() {
    var expression = parseSubExpression(0);
    return expression;
  }
  function parseExpectedExpression() {
    var expression = parseExpression();
    if (null == expression) raiseUnexpectedToken('<expression>', token);else return expression;
  }
  function binaryPrecedence(operator) {
    var charCode = operator.charCodeAt(0),
      length = operator.length;
    if (1 === length) {
      switch (charCode) {
        case 94:
          return 12;
        case 42:
        case 47:
        case 37:
          return 10;
        case 43:
        case 45:
          return 9;
        case 38:
          return 6;
        case 126:
          return 5;
        case 124:
          return 4;
        case 60:
        case 62:
          return 3;
      }
    } else if (2 === length) {
      switch (charCode) {
        case 47:
          return 10;
        case 46:
          return 8;
        case 60:
        case 62:
          if ('<<' === operator || '>>' === operator) return 7;
          return 3;
        case 61:
        case 126:
          return 3;
        case 111:
          return 1;
      }
    } else if (97 === charCode && 'and' === operator) return 2;
    return 0;
  }
  function parseSubExpression(minPrecedence) {
    var operator = token.value,
      expression,
      marker;
    if (trackLocations) marker = createLocationMarker();
    if (isUnary(token)) {
      markLocation();
      next();
      var argument = parseSubExpression(10);
      if (argument == null) raiseUnexpectedToken('<expression>', token);
      expression = finishNode(ast.unaryExpression(operator, argument));
    }
    if (null == expression) {
      expression = parsePrimaryExpression();
      if (null == expression) {
        expression = parsePrefixExpression();
      }
    }
    if (null == expression) return null;
    var precedence;
    while (true) {
      operator = token.value;
      precedence = Punctuator === token.type || Keyword === token.type ? binaryPrecedence(operator) : 0;
      if (precedence === 0 || precedence <= minPrecedence) break;
      if ('^' === operator || '..' === operator) precedence--;
      next();
      var right = parseSubExpression(precedence);
      if (null == right) raiseUnexpectedToken('<expression>', token);
      if (trackLocations) locations.push(marker);
      expression = finishNode(ast.binaryExpression(operator, expression, right));
    }
    return expression;
  }
  function parsePrefixExpression() {
    var base, name, marker;
    if (trackLocations) marker = createLocationMarker();
    if (Identifier === token.type) {
      name = token.value;
      base = parseIdentifier();
      if (options.scope) attachScope(base, scopeHasName(name));
    } else if (consume('(')) {
      base = parseExpectedExpression();
      expect(')');
      base.inParens = true;
    } else {
      return null;
    }
    var expression, identifier;
    while (true) {
      if (Punctuator === token.type) {
        switch (token.value) {
          case '[':
            pushLocation(marker);
            next();
            expression = parseExpectedExpression();
            base = finishNode(ast.indexExpression(base, expression));
            expect(']');
            break;
          case '.':
            pushLocation(marker);
            next();
            identifier = parseIdentifier();
            base = finishNode(ast.memberExpression(base, '.', identifier));
            break;
          case ':':
            pushLocation(marker);
            next();
            identifier = parseIdentifier();
            base = finishNode(ast.memberExpression(base, ':', identifier));
            pushLocation(marker);
            base = parseCallExpression(base);
            break;
          case '(':
          case '{':
            pushLocation(marker);
            base = parseCallExpression(base);
            break;
          default:
            return base;
        }
      } else if (StringLiteral === token.type) {
        pushLocation(marker);
        base = parseCallExpression(base);
      } else {
        break;
      }
    }
    return base;
  }
  function parseCallExpression(base) {
    if (Punctuator === token.type) {
      switch (token.value) {
        case '(':
          next();
          var expressions = [];
          var expression = parseExpression();
          if (null != expression) expressions.push(expression);
          while (consume(',')) {
            expression = parseExpectedExpression();
            expressions.push(expression);
          }
          expect(')');
          return finishNode(ast.callExpression(base, expressions));
        case '{':
          markLocation();
          next();
          var table = parseTableConstructor();
          return finishNode(ast.tableCallExpression(base, table));
      }
    } else if (StringLiteral === token.type) {
      return finishNode(ast.stringCallExpression(base, parsePrimaryExpression()));
    }
    raiseUnexpectedToken('function arguments', token);
  }
  function parsePrimaryExpression() {
    var literals = StringLiteral | NumericLiteral | BooleanLiteral | NilLiteral | VarargLiteral,
      value = token.value,
      type = token.type,
      marker;
    if (trackLocations) marker = createLocationMarker();
    if (type & literals) {
      pushLocation(marker);
      var raw = input.slice(token.range[0], token.range[1]);
      next();
      return finishNode(ast.literal(type, value, raw));
    } else if (Keyword === type && 'function' === value) {
      pushLocation(marker);
      next();
      if (options.scope) createScope();
      return parseFunctionDeclaration(null);
    } else if (consume('{')) {
      pushLocation(marker);
      return parseTableConstructor();
    }
  }
  exports.parse = parse;
  function parse(_input, _options) {
    if ('undefined' === typeof _options && 'object' === typeof _input) {
      _options = _input;
      _input = undefined;
    }
    if (!_options) _options = {};
    input = _input || '';
    options = extend(defaultOptions, _options);
    index = 0;
    line = 1;
    lineStart = 0;
    length = input.length;
    scopes = [[]];
    scopeDepth = 0;
    globals = [];
    locations = [];
    if (options.comments) comments = [];
    if (!options.wait) return end();
    return exports;
  }
  exports.write = write;
  function write(_input) {
    input += String(_input);
    length = input.length;
    return exports;
  }
  exports.end = end;
  function end(_input) {
    if ('undefined' !== typeof _input) write(_input);
    if (input && input.substr(0, 2) === '#!') input = input.replace(/^.*/, function (line) {
      return line.replace(/./g, ' ');
    });
    length = input.length;
    trackLocations = options.locations || options.ranges;
    lookahead = {
      value: '<eof>'
    };
    lookahead = lex();
    var chunk = parseChunk();
    if (options.comments) chunk.comments = comments;
    if (options.scope) chunk.globals = globals;
    if (locations.length > 0) throw new Error('Location tracking failed. This is most likely a bug in luaparse');
    return chunk;
  }
});