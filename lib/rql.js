'use strict';
/*

     Vladimir Dronnikov 2011 dronnikov@gmail.com

     Redistribution and use in source and binary forms, with or without
     modification, are permitted provided that the following conditions are
     met:

     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above
       copyright notice, this list of conditions and the following disclaimer
       in the documentation and/or other materials provided with the
       distribution.
     * Neither the name of the  nor the names of its
       contributors may be used to endorse or promote products derived from
       this software without specific prior written permission.

     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
     A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
     OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
     SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
     LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
     DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
     THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
     (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
     OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
/*
	Rewrite of kriszyp's RQL https://github.com/kriszyp/rql
*/var Query, autoConverted, converters, encodeString, encodeValue, jsOperatorMap, operatorMap, operators, parse, plusMinus, query, queryToString, requires_array, stringToValue, stringify, valid_funcs, valid_operators;
var __hasProp = Object.prototype.hasOwnProperty, __slice = Array.prototype.slice;
operatorMap = {
  '=': 'eq',
  '==': 'eq',
  '>': 'gt',
  '>=': 'ge',
  '<': 'lt',
  '<=': 'le',
  '!=': 'ne'
};
Query = (function() {
  function Query(query, parameters) {
    var k, leftoverCharacters, removeParentProperty, term, topTerm, v;
    if (query == null) {
      query = '';
    }
    term = this;
    term.name = 'and';
    term.args = [];
    topTerm = term;
    if (_.isObject(query)) {
      if (_.isArray(query)) {
        topTerm["in"]('id', query);
        return;
      } else if (query instanceof Query) {
        query = query.toString();
      } else {
        for (k in query) {
          if (!__hasProp.call(query, k)) continue;
          v = query[k];
          term = new Query();
          topTerm.args.push(term);
          term.name = 'eq';
          term.args = [k, v];
        }
        return;
      }
    }
    if (query.charAt(0) === '?') {
      query = query.substring(1);
    }
    if (query.indexOf('/') >= 0) {
      query = query.replace(/[\+\*\$\-:\w%\._]*\/[\+\*\$\-:\w%\._\/]*/g, function(slashed) {
        return '(' + slashed.replace(/\//g, ',') + ')';
      });
    }
    query = query.replace(/(\([\+\*\$\-:\w%\._,]+\)|[\+\*\$\-:\w%\._]*|)([<>!]?=(?:[\w]*=)?|>|<)(\([\+\*\$\-:\w%\._,]+\)|[\+\*\$\-:\w%\._]*|)/g, function(t, property, operator, value) {
      if (operator.length < 3) {
        if (!operatorMap.hasOwnProperty(operator)) {
          throw new URIError('Illegal operator ' + operator);
        }
        operator = operatorMap[operator];
      } else {
        operator = operator.substring(1, operator.length - 1);
      }
      return operator + '(' + property + ',' + value + ')';
    });
    if (query.charAt(0) === '?') {
      query = query.substring(1);
    }
    leftoverCharacters = query.replace(/(\))|([&\|,])?([\+\*\$\-:\w%\._]*)(\(?)/g, function(t, closedParen, delim, propertyOrValue, openParen) {
      var isArray, newTerm, op;
      if (delim) {
        if (delim === '&') {
          op = 'and';
        } else if (delim === '|') {
          op = 'or';
        }
        if (op) {
          if (!term.name) {
            term.name = op;
          } else if (term.name !== op) {
            throw new Error('Can not mix conjunctions within a group, use parenthesis around each set of same conjuctions (& and |)');
          }
        }
      }
      if (openParen) {
        newTerm = new Query();
        newTerm.name = propertyOrValue;
        newTerm.parent = term;
        term.args.push(newTerm);
        term = newTerm;
      } else if (closedParen) {
        isArray = !term.name;
        term = term.parent;
        if (!term) {
          throw new URIError('Closing parenthesis without an opening parenthesis');
        }
        if (isArray) {
          term.args.push(term.args.pop().args);
        }
      } else if (propertyOrValue || delim === ',') {
        term.args.push(stringToValue(propertyOrValue, parameters));
      }
      return '';
    });
    if (term.parent) {
      throw new URIError('Opening parenthesis without a closing parenthesis');
    }
    if (leftoverCharacters) {
      throw new URIError('Illegal character in query string encountered ' + leftoverCharacters);
    }
    removeParentProperty = function(obj) {
      if (obj != null ? obj.args : void 0) {
        delete obj.parent;
        _.each(obj.args, removeParentProperty);
      }
      return obj;
    };
    removeParentProperty(topTerm);
    topTerm;
  }
  Query.prototype.toString = function() {
    if (this.name === 'and') {
      return _.map(this.args, queryToString).join('&');
    } else {
      return queryToString(this);
    }
  };
  Query.prototype.where = function(query) {
    this.args = this.args.concat(new Query(query).args);
    return this;
  };
  Query.prototype.toSQL = function(options) {
    if (options == null) {
      options = {};
    }
    throw Error('Not implemented');
  };
  Query.prototype.toMongo = function(options) {
    var search, walk;
    if (options == null) {
      options = {};
    }
    walk = function(name, terms) {
      var search;
      search = {};
      _.each(terms || [], function(term) {
        var args, func, key, limit, nested, pm, regex, x, y, _ref;
        if (term == null) {
          term = {};
        }
        func = term.name;
        args = term.args;
        if (!(func && args)) {
          return;
        }
        if (_.isString((_ref = args[0]) != null ? _ref.name : void 0) && _.isArray(args[0].args)) {
          if (_.include(valid_operators, func)) {
            nested = walk(func, args);
            search['$' + func] = nested;
          }
        } else {
          if (func === 'sort' || func === 'select' || func === 'values') {
            if (func === 'values') {
              func = 'select';
              options.values = true;
            }
            pm = plusMinus[func];
            options[func] = {};
            args = _.map(args, function(x) {
              if (x === 'id' || x === '+id') {
                return '_id';
              } else {
                return x;
              }
            });
            args = _.map(args, function(x) {
              if (x === '-id') {
                return '-_id';
              } else {
                return x;
              }
            });
            _.each(args, function(x, index) {
              var a;
              if (_.isArray(x)) {
                x = x.join('.');
              }
              a = /([-+]*)(.+)/.exec(x);
              return options[func][a[2]] = pm[(a[1].charAt(0) === '-') * 1] * (index + 1);
            });
            return;
          } else if (func === 'limit') {
            limit = args;
            options.skip = +limit[1] || 0;
            options.limit = +limit[0] || Infinity;
            options.needCount = true;
            return;
          }
          if (func === 'le') {
            func = 'lte';
          } else if (func === 'ge') {
            func = 'gte';
          }
          key = args[0];
          args = args.slice(1);
          if (_.isArray(key)) {
            key = key.join('.');
          }
          if (String(key).charAt(0) === '$') {
            return;
          }
          if (key === 'id') {
            key = '_id';
          }
          if (_.include(requires_array, func)) {
            args = args[0];
          } else if (func === 'match') {
            func = 'eq';
            regex = new RegExp;
            regex.compile.apply(regex, args);
            args = regex;
          } else {
            args = args.length === 1 ? args[0] : args.join();
          }
          if (func === 'ne' && _.isRegExp(args)) {
            func = 'not';
          }
          if (_.include(valid_funcs, func)) {
            func = '$' + func;
          } else {
            return;
          }
          if (name === 'or') {
            if (!_.isArray(search)) {
              search = [];
            }
            x = {};
            if (func === '$eq') {
              x[key] = args;
            } else {
              y = {};
              y[func] = args;
              x[key] = y;
            }
            search.push(x);
          } else {
            if (search[key] === void 0) {
              search[key] = {};
            }
            if (_.isObject(search[key]) && !_.isArray(search[key])) {
              search[key][func] = args;
            }
            if (func === '$eq') {
              search[key] = args;
            }
          }
        }
      });
      return search;
    };
    search = walk(this.name, this.args);
    if (options.select) {
      options.fields = options.select;
      delete options.select;
    }
    return {
      meta: options,
      search: search
    };
  };
  return Query;
})();
stringToValue = function(string, parameters) {
  var converter, param_index, parts;
  converter = converters["default"];
  if (string.charAt(0) === '$') {
    param_index = parseInt(string.substring(1), 10) - 1;
    if (param_index >= 0 && parameters) {
      return parameters[param_index];
    } else {
      return;
    }
  }
  if (string.indexOf(':') >= 0) {
    parts = string.split(':', 2);
    converter = converters[parts[0]];
    if (!converter) {
      throw new URIError('Unknown converter ' + parts[0]);
    }
    string = parts[1];
  }
  return converter(string);
};
queryToString = function(part) {
  var mapped;
  if (_.isArray(part)) {
    mapped = _.map(part, function(arg) {
      return queryToString(arg);
    });
    return '(' + mapped.join(',') + ')';
  } else if (part && part.name && part.args) {
    mapped = _.map(part.args, function(arg) {
      return queryToString(arg);
    });
    return part.name + '(' + mapped.join(',') + ')';
  } else {
    return encodeValue(part);
  }
};
encodeString = function(s) {
  if (_.isString(s)) {
    s = encodeURIComponent(s);
    if (s.match(/[\(\)]/)) {
      s = s.replace('(', '%28').replace(')', '%29');
    }
  }
  return s;
};
encodeValue = function(val) {
  var encoded, i, type;
  if (val === null) {
    return 'null';
  } else if (typeof val === 'undefined') {
    return val;
  }
  if (val !== converters["default"]('' + (val.toISOString && val.toISOString() || val.toString()))) {
    if (_.isRegExp(val)) {
      val = val.toString();
      i = val.lastIndexOf('/');
      type = val.substring(i).indexOf('i') >= 0 ? 're' : 'RE';
      val = encodeString(val.substring(1, i));
      encoded = true;
    } else if (_.isDate(val)) {
      type = 'epoch';
      val = val.getTime();
      encoded = true;
    } else if (_.isString(type)) {
      type = 'string';
      val = encodeString(val);
      encoded = true;
    } else {
      type = typeof val;
    }
    val = [type, val].join(':');
  }
  if (!encoded && _.isString(val)) {
    val = encodeString(val);
  }
  return val;
};
autoConverted = {
  'true': true,
  'false': false,
  'null': null,
  'undefined': void 0,
  'Infinity': Infinity,
  '-Infinity': -Infinity
};
converters = {
  auto: function(string) {
    var number;
    if (autoConverted.hasOwnProperty(string)) {
      return autoConverted[string];
    }
    number = +string;
    if (_.isNaN(number) || number.toString() !== string) {
      string = decodeURIComponent(string);
      return string;
    }
    return number;
  },
  number: function(x) {
    var number;
    number = +x;
    if (_.isNaN(number)) {
      throw new URIError('Invalid number ' + x);
    }
    return number;
  },
  epoch: function(x) {
    var date;
    date = new Date(+x);
    if (!_.isDate(date)) {
      throw new URIError('Invalid date ' + x);
    }
    return date;
  },
  isodate: function(x) {
    var date;
    date = '0000'.substr(0, 4 - x.length) + x;
    date += '0000-01-01T00:00:00Z'.substring(date.length);
    return converters.date(date);
  },
  date: function(x) {
    var date, isoDate;
    isoDate = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2}(?:\.\d*)?)Z$/.exec(x);
    if (isoDate) {
      date = new Date(Date.UTC(+isoDate[1], +isoDate[2] - 1, +isoDate[3], +isoDate[4], +isoDate[5], +isoDate[6]));
    } else {
      date = _.parseDate(x);
    }
    if (!_.isDate(date)) {
      throw new URIError('Invalid date ' + x);
    }
    return date;
  },
  boolean: function(x) {
    if (x === 'false') {
      return false;
    } else {
      return !!x;
    }
  },
  string: function(string) {
    return decodeURIComponent(string);
  },
  re: function(x) {
    return new RegExp(decodeURIComponent(x), 'i');
  },
  RE: function(x) {
    return new RegExp(decodeURIComponent(x));
  },
  glob: function(x) {
    var s;
    s = decodeURIComponent(x).replace(/([\\|\||\(|\)|\[|\{|\^|\$|\*|\+|\?|\.|\<|\>])/g, function(x) {
      return '\\' + x;
    });
    s = s.replace(/\\\*/g, '.*').replace(/\\\?/g, '.?');
    s = s.substring(0, 2) !== '.*' ? '^' + s : s.substring(2);
    s = s.substring(s.length - 2) !== '.*' ? s + '$' : s.substring(0, s.length - 2);
    return new RegExp(s, 'i');
  }
};
converters["default"] = converters.auto;
_.each(['eq', 'ne', 'le', 'ge', 'lt', 'gt', 'between', 'in', 'nin', 'contains', 'ncontains', 'or', 'and'], function(op) {
  return Query.prototype[op] = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    this.args.push({
      name: op,
      args: args
    });
    return this;
  };
});
parse = function(query, parameters) {
  var q;
  q = new Query(query, parameters);
  return q;
  try {
    q = new Query(query, parameters);
  } catch (x) {
    q = new Query;
    q.error = x.message;
  }
  return q;
};
valid_funcs = ['eq', 'ne', 'lt', 'lte', 'gt', 'gte', 'in', 'nin', 'not', 'mod', 'all', 'size', 'exists', 'type', 'elemMatch'];
requires_array = ['in', 'nin', 'all', 'mod'];
valid_operators = ['or', 'and', 'not'];
plusMinus = {
  sort: [1, -1],
  select: [1, 0]
};
_.mixin({
  rql: parse
});
jsOperatorMap = {
  'eq': '===',
  'ne': '!==',
  'le': '<=',
  'ge': '>=',
  'lt': '<',
  'gt': '>'
};
operators = {
  and: function() {
    var cond, conditions, obj, _i, _len;
    obj = arguments[0], conditions = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    for (_i = 0, _len = conditions.length; _i < _len; _i++) {
      cond = conditions[_i];
      if (_.isFunction(cond)) {
        obj = cond(obj);
      }
    }
    return obj;
  },
  or: function() {
    var cond, conditions, list, obj, _i, _len;
    obj = arguments[0], conditions = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    list = [];
    for (_i = 0, _len = conditions.length; _i < _len; _i++) {
      cond = conditions[_i];
      if (_.isFunction(cond)) {
        list = list.concat(cond(obj));
      }
    }
    return _.uniq(list);
  },
  limit: function(list, limit, start) {
    if (start == null) {
      start = 0;
    }
    return list.slice(start, start + limit);
  },
  slice: function(list, start, end) {
    if (start == null) {
      start = 0;
    }
    if (end == null) {
      end = Infinity;
    }
    return list.slice(start, end);
  },
  pick: function() {
    var exclude, include, list, props;
    list = arguments[0], props = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    include = [];
    exclude = [];
    _.each(props, function(x, index) {
      var a, leading;
      leading = _.isArray(x) ? x[0] : x;
      a = /([-+]*)(.+)/.exec(leading);
      if (_.isArray(x)) {
        x[0] = a[2];
      } else {
        x = a[2];
      }
      if (a[1].charAt(0) === '-') {
        return exclude.push(x);
      } else {
        return include.push(x);
      }
    });
    return _.map(list, function(item) {
      var i, n, s, selected, t, value, x, _i, _j, _k, _len, _len2, _len3, _ref;
      if (_.isEmpty(include)) {
        selected = _.clone(item);
      } else {
        selected = {};
        for (_i = 0, _len = include.length; _i < _len; _i++) {
          x = include[_i];
          value = _.get(item, x);
          if (value === void 0) {
            continue;
          }
          if (_.isArray(x)) {
            t = s = selected;
            n = x.slice(-1);
            for (_j = 0, _len2 = x.length; _j < _len2; _j++) {
              i = x[_j];
              (_ref = t[i]) != null ? _ref : t[i] = {};
              s = t;
              t = t[i];
            }
            s[n] = value;
          } else {
            selected[x] = value;
          }
        }
      }
      for (_k = 0, _len3 = exclude.length; _k < _len3; _k++) {
        x = exclude[_k];
        _.get(selected, x, true);
      }
      return selected;
    });
  },
  values: function() {
    return _.map(operators.pick.apply(this, arguments), _.values);
  },
  sort: function() {
    var list, order, props;
    list = arguments[0], props = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    order = [];
    _.each(props, function(x, index) {
      var a, leading;
      leading = _.isArray(x) ? x[0] : x;
      a = /([-+]*)(.+)/.exec(leading);
      if (_.isArray(x)) {
        x[0] = a[2];
      } else {
        x = a[2];
      }
      if (a[1].charAt(0) === '-') {
        return order.push({
          attr: x,
          order: -1
        });
      } else {
        return order.push({
          attr: x,
          order: 1
        });
      }
    });
    return list.sort(function(a, b) {
      var prop, va, vb, _i, _len;
      for (_i = 0, _len = order.length; _i < _len; _i++) {
        prop = order[_i];
        va = _.get(a, prop.attr);
        vb = _.get(b, prop.attr);
        if (va > vb) {
          return prop.order;
        } else {
          if (va !== vb) {
            return -prop.order;
          }
        }
      }
      return 0;
    });
  },
  match: function(list, prop, regex) {
    if (!_.isRegExp(regex)) {
      regex = new RegExp(regex, 'i');
    }
    return _.select(list, function(x) {
      return regex.test(_.get(x, prop));
    });
  },
  nmatch: function(list, prop, regex) {
    if (!_.isRegExp(regex)) {
      regex = new RegExp(regex, 'i');
    }
    return _.select(list, function(x) {
      return !regex.test(_.get(x, prop));
    });
  },
  "in": function(list, prop, values) {
    values = _.ensureArray(values);
    return _.select(list, function(x) {
      return _.include(values, _.get(x, prop));
    });
  },
  nin: function(list, prop, values) {
    values = _.ensureArray(values);
    return _.select(list, function(x) {
      return !_.include(values, _.get(x, prop));
    });
  },
  contains: function(list, prop, value) {
    return _.select(list, function(x) {
      return _.include(_.get(x, prop), value);
    });
  },
  ncontains: function(list, prop, value) {
    return _.select(list, function(x) {
      return !_.include(_.get(x, prop), value);
    });
  },
  between: function(list, prop, minInclusive, maxExclusive) {
    return _.select(list, function(x) {
      var _ref;
      return (minInclusive <= (_ref = _.get(x, prop)) && _ref < maxExclusive);
    });
  },
  nbetween: function(list, prop, minInclusive, maxExclusive) {
    return _.select(list, function(x) {
      var _ref;
      return !((minInclusive <= (_ref = _.get(x, prop)) && _ref < maxExclusive));
    });
  }
};
operators.select = operators.pick;
operators.out = operators.nin;
operators.excludes = operators.ncontains;
operators.distinct = _.uniq;
stringify = function(str) {
  return '"' + String(str).replace(/"/g, '\\"') + '"';
};
query = function(list, query, options) {
  var expr, queryToJS;
  if (options == null) {
    options = {};
  }
  query = parse(query, options.parameters);
  if (query.error) {
    return [];
  }
  queryToJS = function(value) {
    var condition, escaped, item, p, path, prm, testValue, _i, _len;
    if (_.isObject(value) && !_.isRegExp(value)) {
      if (_.isArray(value)) {
        return '[' + _.map(value, queryToJS) + ']';
      } else {
        if (jsOperatorMap.hasOwnProperty(value.name)) {
          path = value.args[0];
          prm = value.args[1];
          item = 'item';
          if (prm === void 0) {
            prm = path;
          } else if (_.isArray(path)) {
            escaped = [];
            for (_i = 0, _len = path.length; _i < _len; _i++) {
              p = path[_i];
              escaped.push(stringify(p));
              item += '&&item[' + escaped.join('][') + ']';
            }
          } else {
            item += '&&item[' + stringify(path) + ']';
          }
          testValue = queryToJS(prm);
          if (_.isRegExp(testValue)) {
            condition = testValue + (".test(" + item + ")");
            if (value.name !== 'eq') {
              condition = "!(" + condition + ")";
            }
          } else {
            condition = item + jsOperatorMap[value.name] + testValue;
          }
          return "function(list){return _.select(list,function(item){return " + condition + ";});}";
        } else if (operators.hasOwnProperty(value.name)) {
          return ("function(list){return operators['" + value.name + "'](") + ['list'].concat(_.map(value.args, queryToJS)).join(',') + ');}';
        } else {
          return "function(list){return _.select(list,function(item){return false;});}";
        }
      }
    } else {
      if (_.isString(value)) {
        return stringify(value);
      } else {
        return value;
      }
    }
  };
  expr = queryToJS(query).slice(15, -1);
  if (list) {
    return (new Function('list, operators', expr))(list, operators);
  } else {
    return expr;
  }
};
_.mixin({
  query: query
});