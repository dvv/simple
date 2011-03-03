/*
    http://www.JSON.org/json2.js
    2011-01-18

    Public Domain.

    NO WARRANTY EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

    See http://www.JSON.org/js.html


    This code should be minified before deployment.
    See http://javascript.crockford.com/jsmin.html

    USE YOUR OWN COPY. IT IS EXTREMELY UNWISE TO LOAD CODE FROM SERVERS YOU DO
    NOT CONTROL.


    This file creates a global JSON object containing two methods: stringify
    and parse.

        JSON.stringify(value, replacer, space)
            value       any JavaScript value, usually an object or array.

            replacer    an optional parameter that determines how object
                        values are stringified for objects. It can be a
                        function or an array of strings.

            space       an optional parameter that specifies the indentation
                        of nested structures. If it is omitted, the text will
                        be packed without extra whitespace. If it is a number,
                        it will specify the number of spaces to indent at each
                        level. If it is a string (such as '\t' or '&nbsp;'),
                        it contains the characters used to indent at each level.

            This method produces a JSON text from a JavaScript value.

            When an object value is found, if the object contains a toJSON
            method, its toJSON method will be called and the result will be
            stringified. A toJSON method does not serialize: it returns the
            value represented by the name/value pair that should be serialized,
            or undefined if nothing should be serialized. The toJSON method
            will be passed the key associated with the value, and this will be
            bound to the value

            For example, this would serialize Dates as ISO strings.

                Date.prototype.toJSON = function (key) {
                    function f(n) {
                        // Format integers to have at least two digits.
                        return n < 10 ? '0' + n : n;
                    }

                    return this.getUTCFullYear()   + '-' +
                         f(this.getUTCMonth() + 1) + '-' +
                         f(this.getUTCDate())      + 'T' +
                         f(this.getUTCHours())     + ':' +
                         f(this.getUTCMinutes())   + ':' +
                         f(this.getUTCSeconds())   + 'Z';
                };

            You can provide an optional replacer method. It will be passed the
            key and value of each member, with this bound to the containing
            object. The value that is returned from your method will be
            serialized. If your method returns undefined, then the member will
            be excluded from the serialization.

            If the replacer parameter is an array of strings, then it will be
            used to select the members to be serialized. It filters the results
            such that only members with keys listed in the replacer array are
            stringified.

            Values that do not have JSON representations, such as undefined or
            functions, will not be serialized. Such values in objects will be
            dropped; in arrays they will be replaced with null. You can use
            a replacer function to replace those with JSON values.
            JSON.stringify(undefined) returns undefined.

            The optional space parameter produces a stringification of the
            value that is filled with line breaks and indentation to make it
            easier to read.

            If the space parameter is a non-empty string, then that string will
            be used for indentation. If the space parameter is a number, then
            the indentation will be that many spaces.

            Example:

            text = JSON.stringify(['e', {pluribus: 'unum'}]);
            // text is '["e",{"pluribus":"unum"}]'


            text = JSON.stringify(['e', {pluribus: 'unum'}], null, '\t');
            // text is '[\n\t"e",\n\t{\n\t\t"pluribus": "unum"\n\t}\n]'

            text = JSON.stringify([new Date()], function (key, value) {
                return this[key] instanceof Date ?
                    'Date(' + this[key] + ')' : value;
            });
            // text is '["Date(---current time---)"]'


        JSON.parse(text, reviver)
            This method parses a JSON text to produce an object or array.
            It can throw a SyntaxError exception.

            The optional reviver parameter is a function that can filter and
            transform the results. It receives each of the keys and values,
            and its return value is used instead of the original value.
            If it returns what it received, then the structure is not modified.
            If it returns undefined then the member is deleted.

            Example:

            // Parse the text. Values that look like ISO date strings will
            // be converted to Date objects.

            myData = JSON.parse(text, function (key, value) {
                var a;
                if (typeof value === 'string') {
                    a =
/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2}(?:\.\d*)?)Z$/.exec(value);
                    if (a) {
                        return new Date(Date.UTC(+a[1], +a[2] - 1, +a[3], +a[4],
                            +a[5], +a[6]));
                    }
                }
                return value;
            });

            myData = JSON.parse('["Date(09/09/2001)"]', function (key, value) {
                var d;
                if (typeof value === 'string' &&
                        value.slice(0, 5) === 'Date(' &&
                        value.slice(-1) === ')') {
                    d = new Date(value.slice(5, -1));
                    if (d) {
                        return d;
                    }
                }
                return value;
            });


    This is a reference implementation. You are free to copy, modify, or
    redistribute.
*/

/*jslint evil: true, strict: false, regexp: false */

/*members "", "\b", "\t", "\n", "\f", "\r", "\"", JSON, "\\", apply,
    call, charCodeAt, getUTCDate, getUTCFullYear, getUTCHours,
    getUTCMinutes, getUTCMonth, getUTCSeconds, hasOwnProperty, join,
    lastIndex, length, parse, prototype, push, replace, slice, stringify,
    test, toJSON, toString, valueOf
*/


// Create a JSON object only if one does not already exist. We create the
// methods in a closure to avoid creating global variables.

var JSON;
if (!JSON) {
    JSON = {};
}

(function () {
    "use strict";

    function f(n) {
        // Format integers to have at least two digits.
        return n < 10 ? '0' + n : n;
    }

    if (typeof Date.prototype.toJSON !== 'function') {

        Date.prototype.toJSON = function (key) {

            return isFinite(this.valueOf()) ?
                this.getUTCFullYear()     + '-' +
                f(this.getUTCMonth() + 1) + '-' +
                f(this.getUTCDate())      + 'T' +
                f(this.getUTCHours())     + ':' +
                f(this.getUTCMinutes())   + ':' +
                f(this.getUTCSeconds())   + 'Z' : null;
        };

        String.prototype.toJSON      =
            Number.prototype.toJSON  =
            Boolean.prototype.toJSON = function (key) {
                return this.valueOf();
            };
    }

    var cx = /[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
        escapable = /[\\\"\x00-\x1f\x7f-\x9f\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,
        gap,
        indent,
        meta = {    // table of character substitutions
            '\b': '\\b',
            '\t': '\\t',
            '\n': '\\n',
            '\f': '\\f',
            '\r': '\\r',
            '"' : '\\"',
            '\\': '\\\\'
        },
        rep;


    function quote(string) {

// If the string contains no control characters, no quote characters, and no
// backslash characters, then we can safely slap some quotes around it.
// Otherwise we must also replace the offending characters with safe escape
// sequences.

        escapable.lastIndex = 0;
        return escapable.test(string) ? '"' + string.replace(escapable, function (a) {
            var c = meta[a];
            return typeof c === 'string' ? c :
                '\\u' + ('0000' + a.charCodeAt(0).toString(16)).slice(-4);
        }) + '"' : '"' + string + '"';
    }


    function str(key, holder) {

// Produce a string from holder[key].

        var i,          // The loop counter.
            k,          // The member key.
            v,          // The member value.
            length,
            mind = gap,
            partial,
            value = holder[key];

// If the value has a toJSON method, call it to obtain a replacement value.

        if (value && typeof value === 'object' &&
                typeof value.toJSON === 'function') {
            value = value.toJSON(key);
        }

// If we were called with a replacer function, then call the replacer to
// obtain a replacement value.

        if (typeof rep === 'function') {
            value = rep.call(holder, key, value);
        }

// What happens next depends on the value's type.

        switch (typeof value) {
        case 'string':
            return quote(value);

        case 'number':

// JSON numbers must be finite. Encode non-finite numbers as null.

            return isFinite(value) ? String(value) : 'null';

        case 'boolean':
        case 'null':

// If the value is a boolean or null, convert it to a string. Note:
// typeof null does not produce 'null'. The case is included here in
// the remote chance that this gets fixed someday.

            return String(value);

// If the type is 'object', we might be dealing with an object or an array or
// null.

        case 'object':

// Due to a specification blunder in ECMAScript, typeof null is 'object',
// so watch out for that case.

            if (!value) {
                return 'null';
            }

// Make an array to hold the partial results of stringifying this object value.

            gap += indent;
            partial = [];

// Is the value an array?

            if (Object.prototype.toString.apply(value) === '[object Array]') {

// The value is an array. Stringify every element. Use null as a placeholder
// for non-JSON values.

                length = value.length;
                for (i = 0; i < length; i += 1) {
                    partial[i] = str(i, value) || 'null';
                }

// Join all of the elements together, separated with commas, and wrap them in
// brackets.

                v = partial.length === 0 ? '[]' : gap ?
                    '[\n' + gap + partial.join(',\n' + gap) + '\n' + mind + ']' :
                    '[' + partial.join(',') + ']';
                gap = mind;
                return v;
            }

// If the replacer is an array, use it to select the members to be stringified.

            if (rep && typeof rep === 'object') {
                length = rep.length;
                for (i = 0; i < length; i += 1) {
                    k = rep[i];
                    if (typeof k === 'string') {
                        v = str(k, value);
                        if (v) {
                            partial.push(quote(k) + (gap ? ': ' : ':') + v);
                        }
                    }
                }
            } else {

// Otherwise, iterate through all of the keys in the object.

                for (k in value) {
                    if (Object.hasOwnProperty.call(value, k)) {
                        v = str(k, value);
                        if (v) {
                            partial.push(quote(k) + (gap ? ': ' : ':') + v);
                        }
                    }
                }
            }

// Join all of the member texts together, separated with commas,
// and wrap them in braces.

            v = partial.length === 0 ? '{}' : gap ?
                '{\n' + gap + partial.join(',\n' + gap) + '\n' + mind + '}' :
                '{' + partial.join(',') + '}';
            gap = mind;
            return v;
        }
    }

// If the JSON object does not yet have a stringify method, give it one.

    if (typeof JSON.stringify !== 'function') {
        JSON.stringify = function (value, replacer, space) {

// The stringify method takes a value and an optional replacer, and an optional
// space parameter, and returns a JSON text. The replacer can be a function
// that can replace values, or an array of strings that will select the keys.
// A default replacer method can be provided. Use of the space parameter can
// produce text that is more easily readable.

            var i;
            gap = '';
            indent = '';

// If the space parameter is a number, make an indent string containing that
// many spaces.

            if (typeof space === 'number') {
                for (i = 0; i < space; i += 1) {
                    indent += ' ';
                }

// If the space parameter is a string, it will be used as the indent string.

            } else if (typeof space === 'string') {
                indent = space;
            }

// If there is a replacer, it must be a function or an array.
// Otherwise, throw an error.

            rep = replacer;
            if (replacer && typeof replacer !== 'function' &&
                    (typeof replacer !== 'object' ||
                    typeof replacer.length !== 'number')) {
                throw new Error('JSON.stringify');
            }

// Make a fake root object containing our value under the key of ''.
// Return the result of stringifying the value.

            return str('', {'': value});
        };
    }


// If the JSON object does not yet have a parse method, give it one.

    if (typeof JSON.parse !== 'function') {
        JSON.parse = function (text, reviver) {

// The parse method takes a text and an optional reviver function, and returns
// a JavaScript value if the text is a valid JSON text.

            var j;

            function walk(holder, key) {

// The walk method is used to recursively walk the resulting structure so
// that modifications can be made.

                var k, v, value = holder[key];
                if (value && typeof value === 'object') {
                    for (k in value) {
                        if (Object.hasOwnProperty.call(value, k)) {
                            v = walk(value, k);
                            if (v !== undefined) {
                                value[k] = v;
                            } else {
                                delete value[k];
                            }
                        }
                    }
                }
                return reviver.call(holder, key, value);
            }


// Parsing happens in four stages. In the first stage, we replace certain
// Unicode characters with escape sequences. JavaScript handles many characters
// incorrectly, either silently deleting them, or treating them as line endings.

            text = String(text);
            cx.lastIndex = 0;
            if (cx.test(text)) {
                text = text.replace(cx, function (a) {
                    return '\\u' +
                        ('0000' + a.charCodeAt(0).toString(16)).slice(-4);
                });
            }

// In the second stage, we run the text against regular expressions that look
// for non-JSON patterns. We are especially concerned with '()' and 'new'
// because they can cause invocation, and '=' because it can cause mutation.
// But just to be safe, we want to reject all unexpected forms.

// We split the second stage into 4 regexp operations in order to work around
// crippling inefficiencies in IE's and Safari's regexp engines. First we
// replace the JSON backslash pairs with '@' (a non-JSON character). Second, we
// replace all simple value tokens with ']' characters. Third, we delete all
// open brackets that follow a colon or comma or that begin the text. Finally,
// we look to see that the remaining characters are only whitespace or ']' or
// ',' or ':' or '{' or '}'. If that is so, then the text is safe for eval.

            if (/^[\],:{}\s]*$/
                    .test(text.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g, '@')
                        .replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g, ']')
                        .replace(/(?:^|:|,)(?:\s*\[)+/g, ''))) {

// In the third stage we use the eval function to compile the text into a
// JavaScript structure. The '{' operator is subject to a syntactic ambiguity
// in JavaScript: it can begin a block or an object literal. We wrap the text
// in parens to eliminate the ambiguity.

                j = eval('(' + text + ')');

// In the optional fourth stage, we recursively walk the new structure, passing
// each name/value pair to a reviver function for possible transformation.

                return typeof reviver === 'function' ?
                    walk({'': j}, '') : j;
            }

// If the text is not JSON parseable, then a SyntaxError is thrown.

            throw new SyntaxError('JSON.parse');
        };
    }
}());
//     Underscore.js 1.1.4
//     (c) 2011 Jeremy Ashkenas, DocumentCloud Inc.
//     Underscore is freely distributable under the MIT license.
//     Portions of Underscore are inspired or borrowed from Prototype,
//     Oliver Steele's Functional, and John Resig's Micro-Templating.
//     For all details and documentation:
//     http://documentcloud.github.com/underscore

(function() {

  // Baseline setup
  // --------------

  // Establish the root object, `window` in the browser, or `global` on the server.
  var root = this;

  // Save the previous value of the `_` variable.
  var previousUnderscore = root._;

  // Establish the object that gets returned to break out of a loop iteration.
  var breaker = {};

  // Save bytes in the minified (but not gzipped) version:
  var ArrayProto = Array.prototype, ObjProto = Object.prototype;

  // Create quick reference variables for speed access to core prototypes.
  var slice            = ArrayProto.slice,
      unshift          = ArrayProto.unshift,
      toString         = ObjProto.toString,
      hasOwnProperty   = ObjProto.hasOwnProperty;

  // All **ECMAScript 5** native function implementations that we hope to use
  // are declared here.
  var
    nativeForEach      = ArrayProto.forEach,
    nativeMap          = ArrayProto.map,
    nativeReduce       = ArrayProto.reduce,
    nativeReduceRight  = ArrayProto.reduceRight,
    nativeFilter       = ArrayProto.filter,
    nativeEvery        = ArrayProto.every,
    nativeSome         = ArrayProto.some,
    nativeIndexOf      = ArrayProto.indexOf,
    nativeLastIndexOf  = ArrayProto.lastIndexOf,
    nativeIsArray      = Array.isArray,
    nativeKeys         = Object.keys;

  // Create a safe reference to the Underscore object for use below.
  var _ = function(obj) { return new wrapper(obj); };

  // Export the Underscore object for **CommonJS**, with backwards-compatibility
  // for the old `require()` API. If we're not in CommonJS, add `_` to the
  // global object.
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = _;
    _._ = _;
  } else {
    root._ = _;
  }

  // Current version.
  _.VERSION = '1.1.4';

  // Collection Functions
  // --------------------

  // The cornerstone, an `each` implementation, aka `forEach`.
  // Handles objects implementing `forEach`, arrays, and raw objects.
  // Delegates to **ECMAScript 5**'s native `forEach` if available.
  var each = _.each = _.forEach = function(obj, iterator, context) {
    if (obj == null) return;
    if (nativeForEach && obj.forEach === nativeForEach) {
      obj.forEach(iterator, context);
    } else if (_.isNumber(obj.length)) {
      for (var i = 0, l = obj.length; i < l; i++) {
        if (iterator.call(context, obj[i], i, obj) === breaker) return;
      }
    } else {
      for (var key in obj) {
        if (hasOwnProperty.call(obj, key)) {
          if (iterator.call(context, obj[key], key, obj) === breaker) return;
        }
      }
    }
  };

  // Return the results of applying the iterator to each element.
  // Delegates to **ECMAScript 5**'s native `map` if available.
  _.map = function(obj, iterator, context) {
    var results = [];
    if (obj == null) return results;
    if (nativeMap && obj.map === nativeMap) return obj.map(iterator, context);
    each(obj, function(value, index, list) {
      results[results.length] = iterator.call(context, value, index, list);
    });
    return results;
  };

  // **Reduce** builds up a single result from a list of values, aka `inject`,
  // or `foldl`. Delegates to **ECMAScript 5**'s native `reduce` if available.
  _.reduce = _.foldl = _.inject = function(obj, iterator, memo, context) {
    var initial = memo !== void 0;
    if (obj == null) obj = [];
    if (nativeReduce && obj.reduce === nativeReduce) {
      if (context) iterator = _.bind(iterator, context);
      return initial ? obj.reduce(iterator, memo) : obj.reduce(iterator);
    }
    each(obj, function(value, index, list) {
      if (!initial && index === 0) {
        memo = value;
        initial = true;
      } else {
        memo = iterator.call(context, memo, value, index, list);
      }
    });
    if (!initial) throw new TypeError("Reduce of empty array with no initial value");
    return memo;
  };

  // The right-associative version of reduce, also known as `foldr`.
  // Delegates to **ECMAScript 5**'s native `reduceRight` if available.
  _.reduceRight = _.foldr = function(obj, iterator, memo, context) {
    if (obj == null) obj = [];
    if (nativeReduceRight && obj.reduceRight === nativeReduceRight) {
      if (context) iterator = _.bind(iterator, context);
      return memo !== void 0 ? obj.reduceRight(iterator, memo) : obj.reduceRight(iterator);
    }
    var reversed = (_.isArray(obj) ? obj.slice() : _.toArray(obj)).reverse();
    return _.reduce(reversed, iterator, memo, context);
  };

  // Return the first value which passes a truth test. Aliased as `detect`.
  _.find = _.detect = function(obj, iterator, context) {
    var result;
    any(obj, function(value, index, list) {
      if (iterator.call(context, value, index, list)) {
        result = value;
        return true;
      }
    });
    return result;
  };

  // Return all the elements that pass a truth test.
  // Delegates to **ECMAScript 5**'s native `filter` if available.
  // Aliased as `select`.
  _.filter = _.select = function(obj, iterator, context) {
    var results = [];
    if (obj == null) return results;
    if (nativeFilter && obj.filter === nativeFilter) return obj.filter(iterator, context);
    each(obj, function(value, index, list) {
      if (iterator.call(context, value, index, list)) results[results.length] = value;
    });
    return results;
  };

  // Return all the elements for which a truth test fails.
  _.reject = function(obj, iterator, context) {
    var results = [];
    if (obj == null) return results;
    each(obj, function(value, index, list) {
      if (!iterator.call(context, value, index, list)) results[results.length] = value;
    });
    return results;
  };

  // Determine whether all of the elements match a truth test.
  // Delegates to **ECMAScript 5**'s native `every` if available.
  // Aliased as `all`.
  _.every = _.all = function(obj, iterator, context) {
    iterator = iterator || _.identity;
    var result = true;
    if (obj == null) return result;
    if (nativeEvery && obj.every === nativeEvery) return obj.every(iterator, context);
    each(obj, function(value, index, list) {
      if (!(result = result && iterator.call(context, value, index, list))) return breaker;
    });
    return result;
  };

  // Determine if at least one element in the object matches a truth test.
  // Delegates to **ECMAScript 5**'s native `some` if available.
  // Aliased as `any`.
  var any = _.some = _.any = function(obj, iterator, context) {
    iterator = iterator || _.identity;
    var result = false;
    if (obj == null) return result;
    if (nativeSome && obj.some === nativeSome) return obj.some(iterator, context);
    each(obj, function(value, index, list) {
      if (result = iterator.call(context, value, index, list)) return breaker;
    });
    return result;
  };

  // Determine if a given value is included in the array or object using `===`.
  // Aliased as `contains`.
  _.include = _.contains = function(obj, target) {
    var found = false;
    if (obj == null) return found;
    if (nativeIndexOf && obj.indexOf === nativeIndexOf) return obj.indexOf(target) != -1;
    any(obj, function(value) {
      if (found = value === target) return true;
    });
    return found;
  };

  // Invoke a method (with arguments) on every item in a collection.
  _.invoke = function(obj, method) {
    var args = slice.call(arguments, 2);
    return _.map(obj, function(value) {
      return (method ? value[method] : value).apply(value, args);
    });
  };

  // Convenience version of a common use case of `map`: fetching a property.
  _.pluck = function(obj, key) {
    return _.map(obj, function(value){ return value[key]; });
  };

  // Return the maximum element or (element-based computation).
  _.max = function(obj, iterator, context) {
    if (!iterator && _.isArray(obj)) return Math.max.apply(Math, obj);
    var result = {computed : -Infinity};
    each(obj, function(value, index, list) {
      var computed = iterator ? iterator.call(context, value, index, list) : value;
      computed >= result.computed && (result = {value : value, computed : computed});
    });
    return result.value;
  };

  // Return the minimum element (or element-based computation).
  _.min = function(obj, iterator, context) {
    if (!iterator && _.isArray(obj)) return Math.min.apply(Math, obj);
    var result = {computed : Infinity};
    each(obj, function(value, index, list) {
      var computed = iterator ? iterator.call(context, value, index, list) : value;
      computed < result.computed && (result = {value : value, computed : computed});
    });
    return result.value;
  };

  // Sort the object's values by a criterion produced by an iterator.
  _.sortBy = function(obj, iterator, context) {
    return _.pluck(_.map(obj, function(value, index, list) {
      return {
        value : value,
        criteria : iterator.call(context, value, index, list)
      };
    }).sort(function(left, right) {
      var a = left.criteria, b = right.criteria;
      return a < b ? -1 : a > b ? 1 : 0;
    }), 'value');
  };

  // Use a comparator function to figure out at what index an object should
  // be inserted so as to maintain order. Uses binary search.
  _.sortedIndex = function(array, obj, iterator) {
    iterator = iterator || _.identity;
    var low = 0, high = array.length;
    while (low < high) {
      var mid = (low + high) >> 1;
      iterator(array[mid]) < iterator(obj) ? low = mid + 1 : high = mid;
    }
    return low;
  };

  // Safely convert anything iterable into a real, live array.
  _.toArray = function(iterable) {
    if (!iterable)                return [];
    if (iterable.toArray)         return iterable.toArray();
    if (_.isArray(iterable))      return iterable;
    if (_.isArguments(iterable))  return slice.call(iterable);
    return _.values(iterable);
  };

  // Return the number of elements in an object.
  _.size = function(obj) {
    return _.toArray(obj).length;
  };

  // Array Functions
  // ---------------

  // Get the first element of an array. Passing **n** will return the first N
  // values in the array. Aliased as `head`. The **guard** check allows it to work
  // with `_.map`.
  _.first = _.head = function(array, n, guard) {
    return (n != null) && !guard ? slice.call(array, 0, n) : array[0];
  };

  // Returns everything but the first entry of the array. Aliased as `tail`.
  // Especially useful on the arguments object. Passing an **index** will return
  // the rest of the values in the array from that index onward. The **guard**
  // check allows it to work with `_.map`.
  _.rest = _.tail = function(array, index, guard) {
    return slice.call(array, (index == null) || guard ? 1 : index);
  };

  // Get the last element of an array.
  _.last = function(array) {
    return array[array.length - 1];
  };

  // Trim out all falsy values from an array.
  _.compact = function(array) {
    return _.filter(array, function(value){ return !!value; });
  };

  // Return a completely flattened version of an array.
  _.flatten = function(array) {
    return _.reduce(array, function(memo, value) {
      if (_.isArray(value)) return memo.concat(_.flatten(value));
      memo[memo.length] = value;
      return memo;
    }, []);
  };

  // Return a version of the array that does not contain the specified value(s).
  _.without = function(array) {
    var values = slice.call(arguments, 1);
    return _.filter(array, function(value){ return !_.include(values, value); });
  };

  // Produce a duplicate-free version of the array. If the array has already
  // been sorted, you have the option of using a faster algorithm.
  // Aliased as `unique`.
  _.uniq = _.unique = function(array, isSorted) {
    return _.reduce(array, function(memo, el, i) {
      if (0 == i || (isSorted === true ? _.last(memo) != el : !_.include(memo, el))) memo[memo.length] = el;
      return memo;
    }, []);
  };

  // Produce an array that contains every item shared between all the
  // passed-in arrays.
  _.intersect = function(array) {
    var rest = slice.call(arguments, 1);
    return _.filter(_.uniq(array), function(item) {
      return _.every(rest, function(other) {
        return _.indexOf(other, item) >= 0;
      });
    });
  };

  // Zip together multiple lists into a single array -- elements that share
  // an index go together.
  _.zip = function() {
    var args = slice.call(arguments);
    var length = _.max(_.pluck(args, 'length'));
    var results = new Array(length);
    for (var i = 0; i < length; i++) results[i] = _.pluck(args, "" + i);
    return results;
  };

  // If the browser doesn't supply us with indexOf (I'm looking at you, **MSIE**),
  // we need this function. Return the position of the first occurrence of an
  // item in an array, or -1 if the item is not included in the array.
  // Delegates to **ECMAScript 5**'s native `indexOf` if available.
  // If the array is large and already in sort order, pass `true`
  // for **isSorted** to use binary search.
  _.indexOf = function(array, item, isSorted) {
    if (array == null) return -1;
    var i, l;
    if (isSorted) {
      i = _.sortedIndex(array, item);
      return array[i] === item ? i : -1;
    }
    if (nativeIndexOf && array.indexOf === nativeIndexOf) return array.indexOf(item);
    for (i = 0, l = array.length; i < l; i++) if (array[i] === item) return i;
    return -1;
  };


  // Delegates to **ECMAScript 5**'s native `lastIndexOf` if available.
  _.lastIndexOf = function(array, item) {
    if (array == null) return -1;
    if (nativeLastIndexOf && array.lastIndexOf === nativeLastIndexOf) return array.lastIndexOf(item);
    var i = array.length;
    while (i--) if (array[i] === item) return i;
    return -1;
  };

  // Generate an integer Array containing an arithmetic progression. A port of
  // the native Python `range()` function. See
  // [the Python documentation](http://docs.python.org/library/functions.html#range).
  _.range = function(start, stop, step) {
    if (arguments.length <= 1) {
      stop = start || 0;
      start = 0;
    }
    step = arguments[2] || 1;

    var len = Math.max(Math.ceil((stop - start) / step), 0);
    var idx = 0;
    var range = new Array(len);

    while(idx < len) {
      range[idx++] = start;
      start += step;
    }

    return range;
  };

  // Function (ahem) Functions
  // ------------------

  // Create a function bound to a given object (assigning `this`, and arguments,
  // optionally). Binding with arguments is also known as `curry`.
  _.bind = function(func, obj) {
    var args = slice.call(arguments, 2);
    return function() {
      return func.apply(obj || {}, args.concat(slice.call(arguments)));
    };
  };

  // Bind all of an object's methods to that object. Useful for ensuring that
  // all callbacks defined on an object belong to it.
  _.bindAll = function(obj) {
    var funcs = slice.call(arguments, 1);
    if (funcs.length == 0) funcs = _.functions(obj);
    each(funcs, function(f) { obj[f] = _.bind(obj[f], obj); });
    return obj;
  };

  // Memoize an expensive function by storing its results.
  _.memoize = function(func, hasher) {
    var memo = {};
    hasher = hasher || _.identity;
    return function() {
      var key = hasher.apply(this, arguments);
      return hasOwnProperty.call(memo, key) ? memo[key] : (memo[key] = func.apply(this, arguments));
    };
  };

  // Delays a function for the given number of milliseconds, and then calls
  // it with the arguments supplied.
  _.delay = function(func, wait) {
    var args = slice.call(arguments, 2);
    return setTimeout(function(){ return func.apply(func, args); }, wait);
  };

  // Defers a function, scheduling it to run after the current call stack has
  // cleared.
  _.defer = function(func) {
    return _.delay.apply(_, [func, 1].concat(slice.call(arguments, 1)));
  };

  // Internal function used to implement `_.throttle` and `_.debounce`.
  var limit = function(func, wait, debounce) {
    var timeout;
    return function() {
      var context = this, args = arguments;
      var throttler = function() {
        timeout = null;
        func.apply(context, args);
      };
      if (debounce) clearTimeout(timeout);
      if (debounce || !timeout) timeout = setTimeout(throttler, wait);
    };
  };

  // Returns a function, that, when invoked, will only be triggered at most once
  // during a given window of time.
  _.throttle = function(func, wait) {
    return limit(func, wait, false);
  };

  // Returns a function, that, as long as it continues to be invoked, will not
  // be triggered. The function will be called after it stops being called for
  // N milliseconds.
  _.debounce = function(func, wait) {
    return limit(func, wait, true);
  };

  // Returns the first function passed as an argument to the second,
  // allowing you to adjust arguments, run code before and after, and
  // conditionally execute the original function.
  _.wrap = function(func, wrapper) {
    return function() {
      var args = [func].concat(slice.call(arguments));
      return wrapper.apply(this, args);
    };
  };

  // Returns a function that is the composition of a list of functions, each
  // consuming the return value of the function that follows.
  _.compose = function() {
    var funcs = slice.call(arguments);
    return function() {
      var args = slice.call(arguments);
      for (var i=funcs.length-1; i >= 0; i--) {
        args = [funcs[i].apply(this, args)];
      }
      return args[0];
    };
  };

  // Object Functions
  // ----------------

  // Retrieve the names of an object's properties.
  // Delegates to **ECMAScript 5**'s native `Object.keys`
  _.keys = nativeKeys || function(obj) {
    var keys = [];
    for (var key in obj) if (hasOwnProperty.call(obj, key)) keys[keys.length] = key;
    return keys;
  };

  // Retrieve the values of an object's properties.
  _.values = function(obj) {
    return _.map(obj, _.identity);
  };

  // Return a sorted list of the function names available on the object.
  // Aliased as `methods`
  _.functions = _.methods = function(obj) {
    return _.filter(_.keys(obj), function(key){ return _.isFunction(obj[key]); }).sort();
  };

  // Extend a given object with all the properties in passed-in object(s).
  _.extend = function(obj) {
    each(slice.call(arguments, 1), function(source) {
      for (var prop in source) obj[prop] = source[prop];
    });
    return obj;
  };

  // Fill in a given object with default properties.
  _.defaults = function(obj) {
    each(slice.call(arguments, 1), function(source) {
      for (var prop in source) if (obj[prop] == null) obj[prop] = source[prop];
    });
    return obj;
  };

  // Create a (shallow-cloned) duplicate of an object.
  _.clone = function(obj) {
    return _.isArray(obj) ? obj.slice() : _.extend({}, obj);
  };

  // Invokes interceptor with the obj, and then returns obj.
  // The primary purpose of this method is to "tap into" a method chain, in
  // order to perform operations on intermediate results within the chain.
  _.tap = function(obj, interceptor) {
    interceptor(obj);
    return obj;
  };

  // Perform a deep comparison to check if two objects are equal.
  _.isEqual = function(a, b) {
    // Check object identity.
    if (a === b) return true;
    // Different types?
    var atype = typeof(a), btype = typeof(b);
    if (atype != btype) return false;
    // Basic equality test (watch out for coercions).
    if (a == b) return true;
    // One is falsy and the other truthy.
    if ((!a && b) || (a && !b)) return false;
    // Unwrap any wrapped objects.
    if (a._chain) a = a._wrapped;
    if (b._chain) b = b._wrapped;
    // One of them implements an isEqual()?
    if (a.isEqual) return a.isEqual(b);
    // Check dates' integer values.
    if (_.isDate(a) && _.isDate(b)) return a.getTime() === b.getTime();
    // Both are NaN?
    if (_.isNaN(a) && _.isNaN(b)) return false;
    // Compare regular expressions.
    if (_.isRegExp(a) && _.isRegExp(b))
      return a.source     === b.source &&
             a.global     === b.global &&
             a.ignoreCase === b.ignoreCase &&
             a.multiline  === b.multiline;
    // If a is not an object by this point, we can't handle it.
    if (atype !== 'object') return false;
    // Check for different array lengths before comparing contents.
    if (a.length && (a.length !== b.length)) return false;
    // Nothing else worked, deep compare the contents.
    var aKeys = _.keys(a), bKeys = _.keys(b);
    // Different object sizes?
    if (aKeys.length != bKeys.length) return false;
    // Recursive comparison of contents.
    for (var key in a) if (!(key in b) || !_.isEqual(a[key], b[key])) return false;
    return true;
  };

  // Is a given array or object empty?
  _.isEmpty = function(obj) {
    if (_.isArray(obj) || _.isString(obj)) return obj.length === 0;
    for (var key in obj) if (hasOwnProperty.call(obj, key)) return false;
    return true;
  };

  // Is a given value a DOM element?
  _.isElement = function(obj) {
    return !!(obj && obj.nodeType == 1);
  };

  // Is a given value an array?
  // Delegates to ECMA5's native Array.isArray
  _.isArray = nativeIsArray || function(obj) {
    return toString.call(obj) === '[object Array]';
  };

  // Is a given variable an arguments object?
  _.isArguments = function(obj) {
    return !!(obj && hasOwnProperty.call(obj, 'callee'));
  };

  // Is a given value a function?
  _.isFunction = function(obj) {
    return !!(obj && obj.constructor && obj.call && obj.apply);
  };

  // Is a given value a string?
  _.isString = function(obj) {
    return !!(obj === '' || (obj && obj.charCodeAt && obj.substr));
  };

  // Is a given value a number?
  _.isNumber = function(obj) {
    return !!(obj === 0 || (obj && obj.toExponential && obj.toFixed));
  };

  // Is the given value `NaN`? `NaN` happens to be the only value in JavaScript
  // that does not equal itself.
  _.isNaN = function(obj) {
    return obj !== obj;
  };

  // Is a given value a boolean?
  _.isBoolean = function(obj) {
    return obj === true || obj === false;
  };

  // Is a given value a date?
  _.isDate = function(obj) {
    return !!(obj && obj.getTimezoneOffset && obj.setUTCFullYear);
  };

  // Is the given value a regular expression?
  _.isRegExp = function(obj) {
    return !!(obj && obj.test && obj.exec && (obj.ignoreCase || obj.ignoreCase === false));
  };

  // Is a given value equal to null?
  _.isNull = function(obj) {
    return obj === null;
  };

  // Is a given variable undefined?
  _.isUndefined = function(obj) {
    return obj === void 0;
  };

  // Utility Functions
  // -----------------

  // Run Underscore.js in *noConflict* mode, returning the `_` variable to its
  // previous owner. Returns a reference to the Underscore object.
  _.noConflict = function() {
    root._ = previousUnderscore;
    return this;
  };

  // Keep the identity function around for default iterators.
  _.identity = function(value) {
    return value;
  };

  // Run a function **n** times.
  _.times = function (n, iterator, context) {
    for (var i = 0; i < n; i++) iterator.call(context, i);
  };

  // Add your own custom functions to the Underscore object, ensuring that
  // they're correctly added to the OOP wrapper as well.
  _.mixin = function(obj) {
    each(_.functions(obj), function(name){
      addToWrapper(name, _[name] = obj[name]);
    });
  };

  // Generate a unique integer id (unique within the entire client session).
  // Useful for temporary DOM ids.
  var idCounter = 0;
  _.uniqueId = function(prefix) {
    var id = idCounter++;
    return prefix ? prefix + id : id;
  };

  // By default, Underscore uses ERB-style template delimiters, change the
  // following template settings to use alternative delimiters.
  _.templateSettings = {
    evaluate    : /<%([\s\S]+?)%>/g,
    interpolate : /<%=([\s\S]+?)%>/g
  };

  // JavaScript micro-templating, similar to John Resig's implementation.
  // Underscore templating handles arbitrary delimiters, preserves whitespace,
  // and correctly escapes quotes within interpolated code.
  _.template = function(str, data) {
    var c  = _.templateSettings;
    var tmpl = 'var __p=[],print=function(){__p.push.apply(__p,arguments);};' +
      'with(obj||{}){__p.push(\'' +
      str.replace(/\\/g, '\\\\')
         .replace(/'/g, "\\'")
         .replace(c.interpolate, function(match, code) {
           return "'," + code.replace(/\\'/g, "'") + ",'";
         })
         .replace(c.evaluate || null, function(match, code) {
           return "');" + code.replace(/\\'/g, "'")
                              .replace(/[\r\n\t]/g, ' ') + "__p.push('";
         })
         .replace(/\r/g, '\\r')
         .replace(/\n/g, '\\n')
         .replace(/\t/g, '\\t')
         + "');}return __p.join('');";
    var func = new Function('obj', tmpl);
    return data ? func(data) : func;
  };

  // The OOP Wrapper
  // ---------------

  // If Underscore is called as a function, it returns a wrapped object that
  // can be used OO-style. This wrapper holds altered versions of all the
  // underscore functions. Wrapped objects may be chained.
  var wrapper = function(obj) { this._wrapped = obj; };

  // Expose `wrapper.prototype` as `_.prototype`
  _.prototype = wrapper.prototype;

  // Helper function to continue chaining intermediate results.
  var result = function(obj, chain) {
    return chain ? _(obj).chain() : obj;
  };

  // A method to easily add functions to the OOP wrapper.
  var addToWrapper = function(name, func) {
    wrapper.prototype[name] = function() {
      var args = slice.call(arguments);
      unshift.call(args, this._wrapped);
      return result(func.apply(_, args), this._chain);
    };
  };

  // Add all of the Underscore functions to the wrapper object.
  _.mixin(_);

  // Add all mutator Array functions to the wrapper.
  each(['pop', 'push', 'reverse', 'shift', 'sort', 'splice', 'unshift'], function(name) {
    var method = ArrayProto[name];
    wrapper.prototype[name] = function() {
      method.apply(this._wrapped, arguments);
      return result(this._wrapped, this._chain);
    };
  });

  // Add all accessor Array functions to the wrapper.
  each(['concat', 'join', 'slice'], function(name) {
    var method = ArrayProto[name];
    wrapper.prototype[name] = function() {
      return result(method.apply(this._wrapped, arguments), this._chain);
    };
  });

  // Start chaining a wrapped Underscore object.
  wrapper.prototype.chain = function() {
    this._chain = true;
    return this;
  };

  // Extracts the result from a wrapped and chained object.
  wrapper.prototype.value = function() {
    return this._wrapped;
  };

})();
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

*/var __slice = Array.prototype.slice;
_.mixin({
  isObject: function(value) {
    return value && typeof value === 'object';
  },
  ensureArray: function(value) {
    if (!value) {
      if (value === void 0) {
        return [];
      } else {
        return [value];
      }
    }
    if (_.isString(value)) {
      return [value];
    }
    return _.toArray(value);
  },
  toHash: function(list, field) {
    var r;
    r = {};
    _.each(list, function(x) {
      var f;
      f = _.get(x, field);
      return r[f] = x;
    });
    return r;
  },
  freeze: function(obj) {
    if (_.isObject(obj)) {
      Object.freeze(obj);
      _.each(obj, function(v, k) {
        return _.freeze(v);
      });
    }
    return obj;
  },
  proxy: function(obj, exposes) {
    var facet;
    facet = {};
    _.each(exposes, function(definition) {
      var name, prop;
      if (_.isArray(definition)) {
        name = definition[1];
        prop = definition[0];
        if (!_.isFunction(prop)) {
          prop = _.get(obj, prop);
        }
      } else {
        name = definition;
        prop = obj[name];
      }
      if (prop) {
        return facet[name] = prop;
      }
    });
    return Object.freeze(facet);
  },
  get: function(obj, path, remove) {
    var index, name, orig, part, _i, _j, _len, _len2, _ref;
    if (_.isArray(path)) {
      if (remove) {
        _ref = path, path = 2 <= _ref.length ? __slice.call(_ref, 0, _i = _ref.length - 1) : (_i = 0, []), name = _ref[_i++];
        orig = obj;
        for (index = 0, _len = path.length; index < _len; index++) {
          part = path[index];
          obj = obj && obj[part];
        }
        if (obj != null ? obj[name] : void 0) {
          delete obj[name];
        }
        return orig;
      } else {
        for (_j = 0, _len2 = path.length; _j < _len2; _j++) {
          part = path[_j];
          obj = obj && obj[part];
        }
        return obj;
      }
    } else if (path === void 0) {
      return obj;
    } else {
      if (remove) {
        delete obj[path];
        return obj;
      } else {
        return obj[path];
      }
    }
  }
});
_.mixin({
  parseDate: function(value) {
    var date, parts;
    date = new Date(value);
    if (_.isDate(date)) {
      return date;
    }
    parts = String(value).match(/(\d+)/g);
    return new Date(parts[0], (parts[1] || 1) - 1, parts[2] || 1);
  },
  isDate: function(obj) {
    return !!((obj != null ? obj.getTimezoneOffset : void 0) && obj.setUTCFullYear && !_.isNaN(obj.getTime()));
  }
});'use strict';
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
});'use strict';
/*

	JSONSchema Validator - Validates JavaScript objects using JSON Schemas
	(http://www.json.com/json-schema-proposal/)

	Copyright (c) 2007 Kris Zyp SitePen (www.sitepen.com)
	Copyright (c) 2011 Vladimir Dronnikov dronnikov@gmail.com

	Licensed under the MIT (MIT-LICENSE.txt) license

*/
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
	Rewrite of kriszyp's json-schema validator https://github.com/kriszyp/json-schema
*/var coerce, validate;
var __hasProp = Object.prototype.hasOwnProperty;
coerce = function(value, type) {
  var date;
  if (type === 'string') {
    value = value ? '' + value : '';
  } else if (type === 'number' || type === 'integer') {
    if (!_.isNaN(value)) {
      value = +value;
      if (type === 'integer') {
        value = Math.floor(value);
      }
    }
  } else if (type === 'boolean') {
    value = value === 'false' ? false : !!value;
  } else if (type === 'null') {
    value = null;
  } else if (type === 'object') {
    if (typeof JSON != "undefined" && JSON !== null ? JSON.parse : void 0) {
      try {
        value = JSON.parse(value);
      } catch (err) {

      }
    }
  } else if (type === 'array') {
    value = _.ensureArray(value);
  } else if (type === 'date') {
    date = _.parseDate(value);
    if (_.isDate(date)) {
      value = date;
    }
  }
  return value;
};
validate = function(instance, schema, options, callback) {
  var async, asyncs, checkObj, checkProp, context, errors, i, len, _changing, _fn, _len;
  if (options == null) {
    options = {};
  }
  _changing = options.changing;
  asyncs = [];
  errors = [];
  checkProp = function(value, schema, path, i) {
    var addError, checkType, enumeration, itemsIsArray, propDef, v, _len;
    if (path) {
      if (_.isNumber(i)) {
        path += '[' + i + ']';
      } else if (i === void 0) {
        path += '';
      } else {
        path += '.' + i;
      }
    } else {
      path += i;
    }
    addError = function(message) {
      return errors.push({
        property: path,
        message: message
      });
    };
    if ((typeof schema !== 'object' || _.isArray(schema)) && (path || typeof schema !== 'function') && !(schema != null ? schema.type : void 0)) {
      if (_.isFunction(schema)) {
        if (!(value instanceof schema)) {
          addError('type');
        }
      } else if (schema) {
        addError('invalid');
      }
      return null;
    }
    if (_changing && schema.readonly) {
      addError('readonly');
    }
    if (schema["extends"]) {
      checkProp(value, schema["extends"], path, i);
    }
    checkType = function(type, value) {
      var priorErrors, t, theseErrors, unionErrors, _i, _len;
      if (type) {
        if (typeof type === 'string' && type !== 'any' && (type == 'null' ? value !== null : typeof value !== type) &&
						!(type === 'array' && _.isArray(value)) &&
						!(type === 'date' && _.isDate(value)) &&
						!(type === 'integer' && value%1===0)) {
          return [
            {
              property: path,
              message: 'type'
            }
          ];
        }
        if (_.isArray(type)) {
          unionErrors = [];
          for (_i = 0, _len = type.length; _i < _len; _i++) {
            t = type[_i];
            unionErrors = checkType(t, value);
            if (!unionErrors.length) {
              break;
            }
          }
          if (unionErrors.length) {
            return unionErrors;
          }
        } else if (typeof type === 'object') {
          priorErrors = errors;
          errors = [];
          checkProp(value, type, path);
          theseErrors = errors;
          errors = priorErrors;
          return theseErrors;
        }
      }
      return [];
    };
    if (value === void 0) {
      if ((!schema.optional || typeof schema.optional === 'object' && !schema.optional[options.flavor]) && !schema.get && !(schema["default"] != null)) {
        addError('required');
      }
    } else {
      errors = errors.concat(checkType(schema.type, value));
      if (schema.disallow && !checkType(schema.disallow, value).length) {
        addError('disallowed');
      }
      if (value !== null) {
        if (_.isArray(value)) {
          if (schema.items) {
            itemsIsArray = _.isArray(schema.items);
            propDef = schema.items;
            for (i = 0, _len = value.length; i < _len; i++) {
              v = value[i];
              if (itemsIsArray) {
                propDef = schema.items[i];
              }
              if (options.coerce && propDef.type) {
                value[i] = coerce(v, propDef.type);
              }
              errors.concat(checkProp(v, propDef, path, i));
            }
          }
          if (schema.minItems && value.length < schema.minItems) {
            addError('minItems');
          }
          if (schema.maxItems && value.length > schema.maxItems) {
            addError('maxItems');
          }
        } else if (schema.properties || schema.additionalProperties) {
          errors.concat(checkObj(value, schema.properties, path, schema.additionalProperties));
        }
        if (_.isString(value)) {
          if (schema.pattern && !value.match(schema.pattern)) {
            addError('pattern');
          }
          if (schema.maxLength && value.length > schema.maxLength) {
            addError('maxLength');
          }
          if (schema.minLength && value.length < schema.minLength) {
            addError('minLength');
          }
        }
        if (schema.minimum !== void 0 && typeof value === typeof schema.minimum && schema.minimum > value) {
          addError('minimum');
        }
        if (schema.maximum !== void 0 && typeof value === typeof schema.maximum && schema.maximum < value) {
          addError('maximum');
        }
        if (schema["enum"]) {
          enumeration = schema["enum"];
          if (_.isFunction(enumeration)) {
            if (enumeration.length === 2) {
              asyncs.push({
                value: value,
                path: path,
                fetch: enumeration
              });
            } else {
              enumeration = enumeration.call(this);
              if (!_.include(enumeration, value)) {
                addError('enum');
              }
            }
          } else {
            if (!_.include(enumeration, value)) {
              addError('enum');
            }
          }
        }
        if (_.isNumber(schema.maxDecimal) && (new RegExp("\\.[0-9]{" + (schema.maxDecimal + 1) + ",}")).test(value)) {
          addError('digits');
        }
      }
    }
    return null;
  };
  checkObj = function(instance, objTypeDef, path, additionalProp) {
    var i, propDef, requires, value, _ref;
    if (_.isObject(objTypeDef)) {
      if (typeof instance !== 'object' || _.isArray(instance)) {
        errors.push({
          property: path,
          message: 'type'
        });
      }
      for (i in objTypeDef) {
        if (!__hasProp.call(objTypeDef, i)) continue;
        propDef = objTypeDef[i];
        value = instance[i];
        if (value === void 0 && options.existingOnly) {
          continue;
        }
        if (options.veto && (propDef.veto === true || typeof propDef.veto === 'object' && propDef.veto[options.flavor])) {
          delete instance[i];
          continue;
        }
        if (options.flavor === 'get' && !options.coerce) {
          continue;
        }
        if (value === void 0 && (propDef["default"] != null) && options.flavor === 'add') {
          value = instance[i] = propDef["default"];
        }
        if (options.coerce && propDef.type && instance.hasOwnProperty(i)) {
          value = coerce(value, propDef.type);
          instance[i] = value;
        }
        checkProp(value, propDef, path, i);
      }
    }
    for (i in instance) {
      value = instance[i];
      if (instance.hasOwnProperty(i) && !objTypeDef[i] && (additionalProp === false || options.removeAdditionalProps)) {
        if (options.removeAdditionalProps) {
          delete instance[i];
          continue;
        } else {
          errors.push({
            property: path,
            message: 'unspecifed'
          });
        }
      }
      requires = (_ref = objTypeDef[i]) != null ? _ref.requires : void 0;
      if (requires && !instance.hasOwnProperty(requires)) {
        errors.push({
          property: path,
          message: 'requires'
        });
      }
      if ((additionalProp != null ? additionalProp.type : void 0) && !objTypeDef[i]) {
        if (options.coerce && additionalProp.type) {
          value = coerce(value, additionalProp.type);
          instance[i] = value;
          checkProp(value, additionalProp, path, i);
        }
      }
      if (!_changing && (value != null ? value.$schema : void 0)) {
        errors = errors.concat(checkProp(value, value.$schema, path, i));
      }
    }
    return errors;
  };
  if (schema) {
    checkProp(instance, schema, '', _changing || '');
  }
  if (!_changing && (instance != null ? instance.$schema : void 0)) {
    checkProp(instance, instance.$schema, '', '');
  }
  len = asyncs.length;
  if (callback && len) {
    context = this;
    _fn = function(async) {
      return async.fetch.call(context, async.value, function(err) {
        if (err) {
          errors.push({
            property: async.path,
            message: 'enum'
          });
        }
        len -= 1;
        if (!len) {
          return callback(errors.length && errors || null, instance);
        }
      });
    };
    for (i = 0, _len = asyncs.length; i < _len; i++) {
      async = asyncs[i];
      _fn(async);
    }
  } else if (callback) {
    callback(errors.length && errors || null, instance);
  } else {
    return errors.length && errors || null;
  }
};
_.mixin({
  coerce: coerce,
  validate: validate
});//     Backbone.js 0.3.3
//     (c) 2010 Jeremy Ashkenas, DocumentCloud Inc.
//     Backbone may be freely distributed under the MIT license.
//     For all details and documentation:
//     http://documentcloud.github.com/backbone

(function(){

  // Initial Setup
  // -------------

  // The top-level namespace. All public Backbone classes and modules will
  // be attached to this. Exported for both CommonJS and the browser.
  var Backbone;
  if (typeof exports !== 'undefined') {
    Backbone = exports;
  } else {
    Backbone = this.Backbone = {};
  }

  // Current version of the library. Keep in sync with `package.json`.
  Backbone.VERSION = '0.3.3';

  // Require Underscore, if we're on the server, and it's not already present.
  var _ = this._;
  if (!_ && (typeof require !== 'undefined')) _ = require('underscore')._;

  // For Backbone's purposes, either jQuery or Zepto owns the `$` variable.
  var $ = this.jQuery || this.Zepto;

  // Turn on `emulateHTTP` to use support legacy HTTP servers. Setting this option will
  // fake `"PUT"` and `"DELETE"` requests via the `_method` parameter and set a
  // `X-Http-Method-Override` header.
  Backbone.emulateHTTP = false;

  // Turn on `emulateJSON` to support legacy servers that can't deal with direct
  // `application/json` requests ... will encode the body as
  // `application/x-www-form-urlencoded` instead and will send the model in a
  // form param named `model`.
  Backbone.emulateJSON = false;

  // Backbone.Events
  // -----------------

  // A module that can be mixed in to *any object* in order to provide it with
  // custom events. You may `bind` or `unbind` a callback function to an event;
  // `trigger`-ing an event fires all callbacks in succession.
  //
  //     var object = {};
  //     _.extend(object, Backbone.Events);
  //     object.bind('expand', function(){ alert('expanded'); });
  //     object.trigger('expand');
  //
  Backbone.Events = {

    // Bind an event, specified by a string name, `ev`, to a `callback` function.
    // Passing `"all"` will bind the callback to all events fired.
    bind : function(ev, callback) {
      var calls = this._callbacks || (this._callbacks = {});
      var list  = this._callbacks[ev] || (this._callbacks[ev] = []);
      list.push(callback);
      return this;
    },

    // Remove one or many callbacks. If `callback` is null, removes all
    // callbacks for the event. If `ev` is null, removes all bound callbacks
    // for all events.
    unbind : function(ev, callback) {
      var calls;
      if (!ev) {
        this._callbacks = {};
      } else if (calls = this._callbacks) {
        if (!callback) {
          calls[ev] = [];
        } else {
          var list = calls[ev];
          if (!list) return this;
          for (var i = 0, l = list.length; i < l; i++) {
            if (callback === list[i]) {
              list.splice(i, 1);
              break;
            }
          }
        }
      }
      return this;
    },

    // Trigger an event, firing all bound callbacks. Callbacks are passed the
    // same arguments as `trigger` is, apart from the event name.
    // Listening for `"all"` passes the true event name as the first argument.
    trigger : function(ev) {
      var list, calls, i, l;
      if (!(calls = this._callbacks)) return this;
      if (calls[ev]) {
        list = calls[ev].slice(0);
        for (i = 0, l = list.length; i < l; i++) {
          list[i].apply(this, Array.prototype.slice.call(arguments, 1));
        }
      }
      if (calls['all']) {
        list = calls['all'].slice(0);
        for (i = 0, l = list.length; i < l; i++) {
          list[i].apply(this, arguments);
        }
      }
      return this;
    }

  };

  // Backbone.Model
  // --------------

  // Create a new model, with defined attributes. A client id (`cid`)
  // is automatically generated and assigned for you.
  Backbone.Model = function(attributes, options) {
    var defaults;
    attributes || (attributes = {});
    if (defaults = this.defaults) {
      if (_.isFunction(defaults)) defaults = defaults();
      attributes = _.extend({}, defaults, attributes);
    }
    this.attributes = {};
    this._escapedAttributes = {};
    this.cid = _.uniqueId('c');
    this.set(attributes, {silent : true});
    this._changed = false;
    this._previousAttributes = _.clone(this.attributes);
    if (options && options.collection) this.collection = options.collection;
    this.initialize(attributes, options);
  };

  // Attach all inheritable methods to the Model prototype.
  _.extend(Backbone.Model.prototype, Backbone.Events, {

    // A snapshot of the model's previous attributes, taken immediately
    // after the last `"change"` event was fired.
    _previousAttributes : null,

    // Has the item been changed since the last `"change"` event?
    _changed : false,

    // The default name for the JSON `id` attribute is `"id"`. MongoDB and
    // CouchDB users may want to set this to `"_id"`.
    idAttribute : 'id',

    // Initialize is an empty function by default. Override it with your own
    // initialization logic.
    initialize : function(){},

    // Return a copy of the model's `attributes` object.
    toJSON : function() {
      return _.clone(this.attributes);
    },

    // Get the value of an attribute.
    get : function(attr) {
      return this.attributes[attr];
    },

    // Get the HTML-escaped value of an attribute.
    escape : function(attr) {
      var html;
      if (html = this._escapedAttributes[attr]) return html;
      var val = this.attributes[attr];
      return this._escapedAttributes[attr] = escapeHTML(val == null ? '' : '' + val);
    },

    // Returns `true` if the attribute contains a value that is not null
    // or undefined.
    has : function(attr) {
      return this.attributes[attr] != null;
    },

    // Set a hash of model attributes on the object, firing `"change"` unless you
    // choose to silence it.
    set : function(attrs, options) {

      // Extract attributes and options.
      options || (options = {});
      if (!attrs) return this;
      if (attrs.attributes) attrs = attrs.attributes;
      var now = this.attributes, escaped = this._escapedAttributes;

      // Run validation.
      if (!options.silent && this.validate && !this._performValidation(attrs, options)) return false;

      // Check for changes of `id`.
      if (this.idAttribute in attrs) this.id = attrs[this.idAttribute];

      // Update attributes.
      for (var attr in attrs) {
        var val = attrs[attr];
        if (!_.isEqual(now[attr], val)) {
          now[attr] = val;
          delete escaped[attr];
          this._changed = true;
          if (!options.silent) this.trigger('change:' + attr, this, val, options);
        }
      }

      // Fire the `"change"` event, if the model has been changed.
      if (!options.silent && this._changed) this.change(options);
      return this;
    },

    // Remove an attribute from the model, firing `"change"` unless you choose
    // to silence it. `unset` is a noop if the attribute doesn't exist.
    unset : function(attr, options) {
      if (!(attr in this.attributes)) return this;
      options || (options = {});
      var value = this.attributes[attr];

      // Run validation.
      var validObj = {};
      validObj[attr] = void 0;
      if (!options.silent && this.validate && !this._performValidation(validObj, options)) return false;

      // Remove the attribute.
      delete this.attributes[attr];
      delete this._escapedAttributes[attr];
      if (attr == this.idAttribute) delete this.id;
      this._changed = true;
      if (!options.silent) {
        this.trigger('change:' + attr, this, void 0, options);
        this.change(options);
      }
      return this;
    },

    // Clear all attributes on the model, firing `"change"` unless you choose
    // to silence it.
    clear : function(options) {
      options || (options = {});
      var old = this.attributes;

      // Run validation.
      var validObj = {};
      for (attr in old) validObj[attr] = void 0;
      if (!options.silent && this.validate && !this._performValidation(validObj, options)) return false;

      this.attributes = {};
      this._escapedAttributes = {};
      this._changed = true;
      if (!options.silent) {
        for (attr in old) {
          this.trigger('change:' + attr, this, void 0, options);
        }
        this.change(options);
      }
      return this;
    },

    // Fetch the model from the server. If the server's representation of the
    // model differs from its current attributes, they will be overriden,
    // triggering a `"change"` event.
    fetch : function(options) {
      options || (options = {});
      var model = this;
      var success = options.success;
      options.success = function(resp) {
        if (!model.set(model.parse(resp), options)) return false;
        if (success) success(model, resp);
      };
      options.error = wrapError(options.error, model, options);
      (this.sync || Backbone.sync).call(this, 'read', this, options);
      return this;
    },

    // Set a hash of model attributes, and sync the model to the server.
    // If the server returns an attributes hash that differs, the model's
    // state will be `set` again.
    save : function(attrs, options) {
      options || (options = {});
      if (attrs && !this.set(attrs, options)) return false;
      var model = this;
      var success = options.success;
      options.success = function(resp) {
        if (!model.set(model.parse(resp), options)) return false;
        if (success) success(model, resp);
      };
      options.error = wrapError(options.error, model, options);
      var method = this.isNew() ? 'create' : 'update';
      (this.sync || Backbone.sync).call(this, method, this, options);
      return this;
    },

    // Destroy this model on the server. Upon success, the model is removed
    // from its collection, if it has one.
    destroy : function(options) {
      options || (options = {});
      var model = this;
      var success = options.success;
      options.success = function(resp) {
        model.trigger('destroy', model, model.collection, options);
        if (success) success(model, resp);
      };
      options.error = wrapError(options.error, model, options);
      (this.sync || Backbone.sync).call(this, 'delete', this, options);
      return this;
    },

    // Default URL for the model's representation on the server -- if you're
    // using Backbone's restful methods, override this to change the endpoint
    // that will be called.
    url : function() {
      var base = getUrl(this.collection) || this.urlRoot || urlError();
      if (this.isNew()) return base;
      return base + (base.charAt(base.length - 1) == '/' ? '' : '/') + encodeURIComponent(this.id);
    },

    // **parse** converts a response into the hash of attributes to be `set` on
    // the model. The default implementation is just to pass the response along.
    parse : function(resp) {
      return resp;
    },

    // Create a new model with identical attributes to this one.
    clone : function() {
      return new this.constructor(this);
    },

    // A model is new if it has never been saved to the server, and has a negative
    // ID.
    isNew : function() {
      return !this.id;
    },

    // Call this method to manually fire a `change` event for this model.
    // Calling this will cause all objects observing the model to update.
    change : function(options) {
      this.trigger('change', this, options);
      this._previousAttributes = _.clone(this.attributes);
      this._changed = false;
    },

    // Determine if the model has changed since the last `"change"` event.
    // If you specify an attribute name, determine if that attribute has changed.
    hasChanged : function(attr) {
      if (attr) return this._previousAttributes[attr] != this.attributes[attr];
      return this._changed;
    },

    // Return an object containing all the attributes that have changed, or false
    // if there are no changed attributes. Useful for determining what parts of a
    // view need to be updated and/or what attributes need to be persisted to
    // the server.
    changedAttributes : function(now) {
      now || (now = this.attributes);
      var old = this._previousAttributes;
      var changed = false;
      for (var attr in now) {
        if (!_.isEqual(old[attr], now[attr])) {
          changed = changed || {};
          changed[attr] = now[attr];
        }
      }
      return changed;
    },

    // Get the previous value of an attribute, recorded at the time the last
    // `"change"` event was fired.
    previous : function(attr) {
      if (!attr || !this._previousAttributes) return null;
      return this._previousAttributes[attr];
    },

    // Get all of the attributes of the model at the time of the previous
    // `"change"` event.
    previousAttributes : function() {
      return _.clone(this._previousAttributes);
    },

    // Run validation against a set of incoming attributes, returning `true`
    // if all is well. If a specific `error` callback has been passed,
    // call that instead of firing the general `"error"` event.
    _performValidation : function(attrs, options) {
      var error = this.validate(attrs);
      if (error) {
        if (options.error) {
          options.error(this, error);
        } else {
          this.trigger('error', this, error, options);
        }
        return false;
      }
      return true;
    }

  });

  // Backbone.Collection
  // -------------------

  // Provides a standard collection class for our sets of models, ordered
  // or unordered. If a `comparator` is specified, the Collection will maintain
  // its models in sort order, as they're added and removed.
  Backbone.Collection = function(models, options) {
    options || (options = {});
    if (options.comparator) {
      this.comparator = options.comparator;
      delete options.comparator;
    }
    _.bindAll(this, '_onModelEvent', '_removeReference');
    this._reset();
    if (models) this.refresh(models, {silent: true});
    this.initialize(models, options);
  };

  // Define the Collection's inheritable methods.
  _.extend(Backbone.Collection.prototype, Backbone.Events, {

    // The default model for a collection is just a **Backbone.Model**.
    // This should be overridden in most cases.
    model : Backbone.Model,

    // Initialize is an empty function by default. Override it with your own
    // initialization logic.
    initialize : function(){},

    // The JSON representation of a Collection is an array of the
    // models' attributes.
    toJSON : function() {
      return this.map(function(model){ return model.toJSON(); });
    },

    // Add a model, or list of models to the set. Pass **silent** to avoid
    // firing the `added` event for every new model.
    add : function(models, options) {
      if (_.isArray(models)) {
        for (var i = 0, l = models.length; i < l; i++) {
          this._add(models[i], options);
        }
      } else {
        this._add(models, options);
      }
      return this;
    },

    // Remove a model, or a list of models from the set. Pass silent to avoid
    // firing the `removed` event for every model removed.
    remove : function(models, options) {
      if (_.isArray(models)) {
        for (var i = 0, l = models.length; i < l; i++) {
          this._remove(models[i], options);
        }
      } else {
        this._remove(models, options);
      }
      return this;
    },

    // Get a model from the set by id.
    get : function(id) {
      if (id == null) return null;
      return this._byId[id.id != null ? id.id : id];
    },

    // Get a model from the set by client id.
    getByCid : function(cid) {
      return cid && this._byCid[cid.cid || cid];
    },

    // Get the model at the given index.
    at: function(index) {
      return this.models[index];
    },

    // Force the collection to re-sort itself. You don't need to call this under normal
    // circumstances, as the set will maintain sort order as each item is added.
    sort : function(options) {
      options || (options = {});
      if (!this.comparator) throw new Error('Cannot sort a set without a comparator');
      this.models = this.sortBy(this.comparator);
      if (!options.silent) this.trigger('refresh', this, options);
      return this;
    },

    // Pluck an attribute from each model in the collection.
    pluck : function(attr) {
      return _.map(this.models, function(model){ return model.get(attr); });
    },

    // When you have more items than you want to add or remove individually,
    // you can refresh the entire set with a new list of models, without firing
    // any `added` or `removed` events. Fires `refresh` when finished.
    refresh : function(models, options) {
      models  || (models = []);
      options || (options = {});
      this.each(this._removeReference);
      this._reset();
      this.add(models, {silent: true});
      if (!options.silent) this.trigger('refresh', this, options);
      return this;
    },

    // Fetch the default set of models for this collection, refreshing the
    // collection when they arrive. If `add: true` is passed, appends the
    // models to the collection instead of refreshing.
    fetch : function(options) {
      options || (options = {});
      var collection = this;
      var success = options.success;
      options.success = function(resp) {
        collection[options.add ? 'add' : 'refresh'](collection.parse(resp), options);
        if (success) success(collection, resp);
      };
      options.error = wrapError(options.error, collection, options);
      (this.sync || Backbone.sync).call(this, 'read', this, options);
      return this;
    },

    // Create a new instance of a model in this collection. After the model
    // has been created on the server, it will be added to the collection.
    create : function(model, options) {
      var coll = this;
      options || (options = {});
      if (!(model instanceof Backbone.Model)) {
        var attrs = model;
        model = new this.model(null, {collection: coll});
        if (!model.set(attrs)) return false;
      } else {
        model.collection = coll;
      }
      var success = options.success;
      options.success = function(nextModel, resp) {
        coll.add(nextModel);
        if (success) success(nextModel, resp);
      };
      return model.save(null, options);
    },

    // **parse** converts a response into a list of models to be added to the
    // collection. The default implementation is just to pass it through.
    parse : function(resp) {
      return resp;
    },

    // Proxy to _'s chain. Can't be proxied the same way the rest of the
    // underscore methods are proxied because it relies on the underscore
    // constructor.
    chain: function () {
      return _(this.models).chain();
    },

    // Reset all internal state. Called when the collection is refreshed.
    _reset : function(options) {
      this.length = 0;
      this.models = [];
      this._byId  = {};
      this._byCid = {};
    },

    // Internal implementation of adding a single model to the set, updating
    // hash indexes for `id` and `cid` lookups.
    _add : function(model, options) {
      options || (options = {});
      if (!(model instanceof Backbone.Model)) {
        model = new this.model(model, {collection: this});
      }
      var already = this.getByCid(model);
      if (already) throw new Error(["Can't add the same model to a set twice", already.id]);
      this._byId[model.id] = model;
      this._byCid[model.cid] = model;
      if (!model.collection) {
        model.collection = this;
      }
      var index = this.comparator ? this.sortedIndex(model, this.comparator) : this.length;
      this.models.splice(index, 0, model);
      model.bind('all', this._onModelEvent);
      this.length++;
      if (!options.silent) model.trigger('add', model, this, options);
      return model;
    },

    // Internal implementation of removing a single model from the set, updating
    // hash indexes for `id` and `cid` lookups.
    _remove : function(model, options) {
      options || (options = {});
      model = this.getByCid(model) || this.get(model);
      if (!model) return null;
      delete this._byId[model.id];
      delete this._byCid[model.cid];
      this.models.splice(this.indexOf(model), 1);
      this.length--;
      if (!options.silent) model.trigger('remove', model, this, options);
      this._removeReference(model);
      return model;
    },

    // Internal method to remove a model's ties to a collection.
    _removeReference : function(model) {
      if (this == model.collection) {
        delete model.collection;
      }
      model.unbind('all', this._onModelEvent);
    },

    // Internal method called every time a model in the set fires an event.
    // Sets need to update their indexes when models change ids. All other
    // events simply proxy through. "add" and "remove" events that originate
    // in other collections are ignored.
    _onModelEvent : function(ev, model, collection, options) {
      if ((ev == 'add' || ev == 'remove') && collection != this) return;
      if (ev == 'destroy') {
        this._remove(model, options);
      }
      if (ev === 'change:' + model.idAttribute) {
        delete this._byId[model.previous(model.idAttribute)];
        this._byId[model.id] = model;
      }
      this.trigger.apply(this, arguments);
    }

  });

  // Underscore methods that we want to implement on the Collection.
  var methods = ['forEach', 'each', 'map', 'reduce', 'reduceRight', 'find', 'detect',
    'filter', 'select', 'reject', 'every', 'all', 'some', 'any', 'include',
    'invoke', 'max', 'min', 'sortBy', 'sortedIndex', 'toArray', 'size',
    'first', 'rest', 'last', 'without', 'indexOf', 'lastIndexOf', 'isEmpty'];

  // Mix in each Underscore method as a proxy to `Collection#models`.
  _.each(methods, function(method) {
    Backbone.Collection.prototype[method] = function() {
      return _[method].apply(_, [this.models].concat(_.toArray(arguments)));
    };
  });

  // Backbone.Controller
  // -------------------

  // Controllers map faux-URLs to actions, and fire events when routes are
  // matched. Creating a new one sets its `routes` hash, if not set statically.
  Backbone.Controller = function(options) {
    options || (options = {});
    if (options.routes) this.routes = options.routes;
    this._bindRoutes();
    this.initialize(options);
  };

  // Cached regular expressions for matching named param parts and splatted
  // parts of route strings.
  var namedParam    = /:([\w\d]+)/g;
  var splatParam    = /\*([\w\d]+)/g;
  var escapeRegExp  = /[-[\]{}()+?.,\\^$|#\s]/g;

  // Set up all inheritable **Backbone.Controller** properties and methods.
  _.extend(Backbone.Controller.prototype, Backbone.Events, {

    // Initialize is an empty function by default. Override it with your own
    // initialization logic.
    initialize : function(){},

    // Manually bind a single named route to a callback. For example:
    //
    //     this.route('search/:query/p:num', 'search', function(query, num) {
    //       ...
    //     });
    //
    route : function(route, name, callback) {
      Backbone.history || (Backbone.history = new Backbone.History);
      if (!_.isRegExp(route)) route = this._routeToRegExp(route);
      Backbone.history.route(route, _.bind(function(fragment) {
        var args = this._extractParameters(route, fragment);
        callback.apply(this, args);
        this.trigger.apply(this, ['route:' + name].concat(args));
      }, this));
    },

    // Simple proxy to `Backbone.history` to save a fragment into the history,
    // without triggering routes.
    saveLocation : function(fragment) {
      Backbone.history.saveLocation(fragment);
    },

    // Bind all defined routes to `Backbone.history`. We have to reverse the
    // order of the routes here to support behavior where the most general
    // routes can be defined at the bottom of the route map.
    _bindRoutes : function() {
      if (!this.routes) return;
      var routes = [];
      for (var route in this.routes) {
        routes.unshift([route, this.routes[route]]);
      }
      for (var i = 0, l = routes.length; i < l; i++) {
        this.route(routes[i][0], routes[i][1], this[routes[i][1]]);
      }
    },

    // Convert a route string into a regular expression, suitable for matching
    // against the current location fragment.
    _routeToRegExp : function(route) {
      route = route.replace(escapeRegExp, "\\$&")
                   .replace(namedParam, "([^\/]*)")
                   .replace(splatParam, "(.*?)");
      return new RegExp('^' + route + '$');
    },

    // Given a route, and a URL fragment that it matches, return the array of
    // extracted parameters.
    _extractParameters : function(route, fragment) {
      return route.exec(fragment).slice(1);
    }

  });

  // Backbone.History
  // ----------------

  // Handles cross-browser history management, based on URL hashes. If the
  // browser does not support `onhashchange`, falls back to polling.
  Backbone.History = function() {
    this.handlers = [];
    this.fragment = this.getFragment();
    _.bindAll(this, 'checkUrl');
  };

  // Cached regex for cleaning hashes.
  var hashStrip = /^#*/;

  // Has the history handling already been started?
  var historyStarted = false;

  // Set up all inheritable **Backbone.History** properties and methods.
  _.extend(Backbone.History.prototype, {

    // The default interval to poll for hash changes, if necessary, is
    // twenty times a second.
    interval: 50,

    // Get the cross-browser normalized URL fragment.
    getFragment : function(loc) {
      return (loc || window.location).hash.replace(hashStrip, '');
    },

    // Start the hash change handling, returning `true` if the current URL matches
    // an existing route, and `false` otherwise.
    start : function() {
      if (historyStarted) throw new Error("Backbone.history has already been started");
      var docMode = document.documentMode;
      var oldIE = ($.browser.msie && (!docMode || docMode <= 7));
      if (oldIE) {
        this.iframe = $('<iframe src="javascript:0" tabindex="-1" />').hide().appendTo('body')[0].contentWindow;
      }
      if ('onhashchange' in window && !oldIE) {
        $(window).bind('hashchange', this.checkUrl);
      } else {
        setInterval(this.checkUrl, this.interval);
      }
      historyStarted = true;
      return this.loadUrl();
    },

    // Add a route to be tested when the hash changes. Routes added later may
    // override previous routes.
    route : function(route, callback) {
      this.handlers.unshift({route : route, callback : callback});
    },

    // Checks the current URL to see if it has changed, and if it has,
    // calls `loadUrl`, normalizing across the hidden iframe.
    checkUrl : function() {
      var current = this.getFragment();
      if (current == this.fragment && this.iframe) {
        current = this.getFragment(this.iframe.location);
      }
      if (current == this.fragment ||
          current == decodeURIComponent(this.fragment)) return false;
      if (this.iframe) {
        window.location.hash = this.iframe.location.hash = current;
      }
      this.loadUrl();
    },

    // Attempt to load the current URL fragment. If a route succeeds with a
    // match, returns `true`. If no defined routes matches the fragment,
    // returns `false`.
    loadUrl : function() {
      var fragment = this.fragment = this.getFragment();
      var matched = _.any(this.handlers, function(handler) {
        if (handler.route.test(fragment)) {
          handler.callback(fragment);
          return true;
        }
      });
      return matched;
    },

    // Save a fragment into the hash history. You are responsible for properly
    // URL-encoding the fragment in advance. This does not trigger
    // a `hashchange` event.
    saveLocation : function(fragment) {
      fragment = (fragment || '').replace(hashStrip, '');
      if (this.fragment == fragment) return;
      window.location.hash = this.fragment = fragment;
      if (this.iframe && (fragment != this.getFragment(this.iframe.location))) {
        this.iframe.document.open().close();
        this.iframe.location.hash = fragment;
      }
    }

  });

  // Backbone.View
  // -------------

  // Creating a Backbone.View creates its initial element outside of the DOM,
  // if an existing element is not provided...
  Backbone.View = function(options) {
    this.cid = _.uniqueId('view');
    this._configure(options || {});
    this._ensureElement();
    this.delegateEvents();
    this.initialize(options);
  };

  // Element lookup, scoped to DOM elements within the current view.
  // This should be prefered to global lookups, if you're dealing with
  // a specific view.
  var selectorDelegate = function(selector) {
    return $(selector, this.el);
  };

  // Cached regex to split keys for `delegate`.
  var eventSplitter = /^(\w+)\s*(.*)$/;

  // List of view options to be merged as properties.
  var viewOptions = ['model', 'collection', 'el', 'id', 'attributes', 'className', 'tagName'];

  // Set up all inheritable **Backbone.View** properties and methods.
  _.extend(Backbone.View.prototype, Backbone.Events, {

    // The default `tagName` of a View's element is `"div"`.
    tagName : 'div',

    // Attach the `selectorDelegate` function as the `$` property.
    $       : selectorDelegate,

    // Initialize is an empty function by default. Override it with your own
    // initialization logic.
    initialize : function(){},

    // **render** is the core function that your view should override, in order
    // to populate its element (`this.el`), with the appropriate HTML. The
    // convention is for **render** to always return `this`.
    render : function() {
      return this;
    },

    // Remove this view from the DOM. Note that the view isn't present in the
    // DOM by default, so calling this method may be a no-op.
    remove : function() {
      $(this.el).remove();
      return this;
    },

    // For small amounts of DOM Elements, where a full-blown template isn't
    // needed, use **make** to manufacture elements, one at a time.
    //
    //     var el = this.make('li', {'class': 'row'}, this.model.get('title'));
    //
    make : function(tagName, attributes, content) {
      var el = document.createElement(tagName);
      if (attributes) $(el).attr(attributes);
      if (content) $(el).html(content);
      return el;
    },

    // Set callbacks, where `this.callbacks` is a hash of
    //
    // *{"event selector": "callback"}*
    //
    //     {
    //       'mousedown .title':  'edit',
    //       'click .button':     'save'
    //     }
    //
    // pairs. Callbacks will be bound to the view, with `this` set properly.
    // Uses event delegation for efficiency.
    // Omitting the selector binds the event to `this.el`.
    // This only works for delegate-able events: not `focus`, `blur`, and
    // not `change`, `submit`, and `reset` in Internet Explorer.
    delegateEvents : function(events) {
      if (!(events || (events = this.events))) return;
      $(this.el).unbind('.delegateEvents' + this.cid);
      for (var key in events) {
        var methodName = events[key];
        var match = key.match(eventSplitter);
        var eventName = match[1], selector = match[2];
        var method = _.bind(this[methodName], this);
        eventName += '.delegateEvents' + this.cid;
        if (selector === '') {
          $(this.el).bind(eventName, method);
        } else {
          $(this.el).delegate(selector, eventName, method);
        }
      }
    },

    // Performs the initial configuration of a View with a set of options.
    // Keys with special meaning *(model, collection, id, className)*, are
    // attached directly to the view.
    _configure : function(options) {
      if (this.options) options = _.extend({}, this.options, options);
      for (var i = 0, l = viewOptions.length; i < l; i++) {
        var attr = viewOptions[i];
        if (options[attr]) this[attr] = options[attr];
      }
      this.options = options;
    },

    // Ensure that the View has a DOM element to render into.
    // If `this.el` is a string, pass it through `$()`, take the first
    // matching element, and re-assign it to `el`. Otherwise, create
    // an element from the `id`, `className` and `tagName` proeprties.
    _ensureElement : function() {
      if (!this.el) {
        var attrs = this.attributes || {};
        if (this.id) attrs.id = this.id;
        if (this.className) attrs['class'] = this.className;
        this.el = this.make(this.tagName, attrs);
      } else if (_.isString(this.el)) {
        this.el = $(this.el).get(0);
      }
    }

  });

  // The self-propagating extend function that Backbone classes use.
  var extend = function (protoProps, classProps) {
    var child = inherits(this, protoProps, classProps);
    child.extend = extend;
    return child;
  };

  // Set up inheritance for the model, collection, and view.
  Backbone.Model.extend = Backbone.Collection.extend =
    Backbone.Controller.extend = Backbone.View.extend = extend;

  // Map from CRUD to HTTP for our default `Backbone.sync` implementation.
  var methodMap = {
    'create': 'POST',
    'update': 'PUT',
    'delete': 'DELETE',
    'read'  : 'GET'
  };

  // Backbone.sync
  // -------------

  // Override this function to change the manner in which Backbone persists
  // models to the server. You will be passed the type of request, and the
  // model in question. By default, uses makes a RESTful Ajax request
  // to the model's `url()`. Some possible customizations could be:
  //
  // * Use `setTimeout` to batch rapid-fire updates into a single request.
  // * Send up the models as XML instead of JSON.
  // * Persist models via WebSockets instead of Ajax.
  //
  // Turn on `Backbone.emulateHTTP` in order to send `PUT` and `DELETE` requests
  // as `POST`, with a `_method` parameter containing the true HTTP method,
  // as well as all requests with the body as `application/x-www-form-urlencoded` instead of
  // `application/json` with the model in a param named `model`.
  // Useful when interfacing with server-side languages like **PHP** that make
  // it difficult to read the body of `PUT` requests.
  Backbone.sync = function(method, model, options) {
    var type = methodMap[method];

    // Default JSON-request options.
    var params = _.extend({
      type:         type,
      contentType:  'application/json',
      dataType:     'json',
      processData:  false
    }, options);

    // Ensure that we have a URL.
    if (!params.url) {
      params.url = getUrl(model) || urlError();
    }

    // Ensure that we have the appropriate request data.
    if (!params.data && model && (method == 'create' || method == 'update')) {
      params.data = JSON.stringify(model.toJSON());
    }

    // For older servers, emulate JSON by encoding the request into an HTML-form.
    if (Backbone.emulateJSON) {
      params.contentType = 'application/x-www-form-urlencoded';
      params.processData = true;
      params.data        = params.data ? {model : params.data} : {};
    }

    // For older servers, emulate HTTP by mimicking the HTTP method with `_method`
    // And an `X-HTTP-Method-Override` header.
    if (Backbone.emulateHTTP) {
      if (type === 'PUT' || type === 'DELETE') {
        if (Backbone.emulateJSON) params.data._method = type;
        params.type = 'POST';
        params.beforeSend = function(xhr) {
          xhr.setRequestHeader('X-HTTP-Method-Override', type);
        };
      }
    }

    // Make the request.
    $.ajax(params);
  };

  // Helpers
  // -------

  // Shared empty constructor function to aid in prototype-chain creation.
  var ctor = function(){};

  // Helper function to correctly set up the prototype chain, for subclasses.
  // Similar to `goog.inherits`, but uses a hash of prototype properties and
  // class properties to be extended.
  var inherits = function(parent, protoProps, staticProps) {
    var child;

    // The constructor function for the new subclass is either defined by you
    // (the "constructor" property in your `extend` definition), or defaulted
    // by us to simply call `super()`.
    if (protoProps && protoProps.hasOwnProperty('constructor')) {
      child = protoProps.constructor;
    } else {
      child = function(){ return parent.apply(this, arguments); };
    }

    // Inherit class (static) properties from parent.
    _.extend(child, parent);

    // Set the prototype chain to inherit from `parent`, without calling
    // `parent`'s constructor function.
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();

    // Add prototype properties (instance properties) to the subclass,
    // if supplied.
    if (protoProps) _.extend(child.prototype, protoProps);

    // Add static properties to the constructor function, if supplied.
    if (staticProps) _.extend(child, staticProps);

    // Correctly set child's `prototype.constructor`, for `instanceof`.
    child.prototype.constructor = child;

    // Set a convenience property in case the parent's prototype is needed later.
    child.__super__ = parent.prototype;

    return child;
  };

  // Helper function to get a URL from a Model or Collection as a property
  // or as a function.
  var getUrl = function(object) {
    if (!(object && object.url)) return null;
    return _.isFunction(object.url) ? object.url() : object.url;
  };

  // Throw an error when a URL is needed, and none is supplied.
  var urlError = function() {
    throw new Error("A 'url' property or function must be specified");
  };

  // Wrap an optional error callback with a fallback error event.
  var wrapError = function(onError, model, options) {
    return function(resp) {
      if (onError) {
        onError(model, resp, options);
      } else {
        model.trigger('error', model, resp, options);
      }
    };
  };

  // Helper function to escape a string for HTML rendering.
  var escapeHTML = function(string) {
    return string.replace(/&(?!\w+;)/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  };

}).call(this);
// Underscore.string
// (c) 2010 Esa-Matti Suuronen <esa-matti aet suuronen dot org>
// Underscore.strings is freely distributable under the terms of the MIT license.
// Documentation: https://github.com/edtsech/underscore.string
// Some code is borrowed from MooTools and Alexandru Marasteanu.

// Version 1.0.1

(function(){
    // ------------------------- Baseline setup ---------------------------------

    // Establish the root object, "window" in the browser, or "global" on the server.
    var root = this;

    var nativeTrim = String.prototype.trim;

    function str_repeat(i, m) {
        for (var o = []; m > 0; o[--m] = i);
        return o.join('');
    }

    function defaultToWhiteSpace(characters){
        if (characters) {
            return _s.escapeRegExp(characters);
        }
        return '\\s';
    }

    var _s = {

        isBlank: function(str){
            return !!str.match(/^\s*$/);
        },

        capitalize : function(str) {
            return str.charAt(0).toUpperCase() + str.substring(1).toLowerCase();
        },

        chop: function(str, step){
            step = step || str.length;
            var arr = [];
            for (var i = 0; i < str.length;) {
                arr.push(str.slice(i,i + step));
                i = i + step;
            }
            return arr;
        },

        clean: function(str){
            return _s.strip(str.replace(/\s+/g, ' '));
        },

        contains: function(str, needle){
            return str.indexOf(needle) !== -1;
        },

        count: function(str, substr){
            var count = 0, index;
            for (var i=0; i < str.length;) {
                index = str.indexOf(substr, i);
                index >= 0 && count++;
                i = i + (index >= 0 ? index : 0) + substr.length;
            }
            return count;
        },

        escapeHTML: function(str) {
            return String(str||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
        },

        unescapeHTML: function(str) {
            return String(str||'').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
        },

        escapeRegExp: function(str){
            // From MooTools core 1.2.4
            return String(str||'').replace(/([-.*+?^${}()|[\]\/\\])/g, '\\$1');
        },

        insert: function(str, i, substr){
            var arr = str.split('');
            arr.splice(i, 0, substr);
            return arr.join('');
        },

        join: function(sep) {
            // TODO: Could this be faster by converting
            // arguments to Array and using array.join(sep)?
            sep = String(sep);
            var str = "";
            for (var i=1; i < arguments.length; i += 1) {
                str += String(arguments[i]);
                if ( i !== arguments.length-1 ) {
                    str += sep;
                }
            }
            return str;
        },

        reverse: function(str){
            return Array.prototype.reverse.apply(str.split('')).join('');
        },

        splice: function(str, i, howmany, substr){
            var arr = str.split('');
            arr.splice(i, howmany, substr);
            return arr.join('');
        },

        startsWith: function(str, starts){
            return str.length >= starts.length && str.substring(0, starts.length) === starts;
        },

        endsWith: function(str, ends){
            return str.length >= ends.length && str.substring(str.length - ends.length) === ends;
        },

        succ: function(str){
            var arr = str.split('');
            arr.splice(str.length-1, 1, String.fromCharCode(str.charCodeAt(str.length-1) + 1));
            return arr.join('');
        },

        titleize: function(str){
            var arr = str.split(' '),
                word;
            for (var i=0; i < arr.length; i++) {
                word = arr[i].split('');
                if(typeof word[0] !== 'undefined') word[0] = word[0].toUpperCase();
                i+1 === arr.length ? arr[i] = word.join('') : arr[i] = word.join('') + ' ';
            }
            return arr.join('');
        },

        trim: function(str, characters){
            if (!characters && nativeTrim) {
                return nativeTrim.call(str);
            }
            characters = defaultToWhiteSpace(characters);
            return str.replace(new RegExp('\^[' + characters + ']+|[' + characters + ']+$', 'g'), '');
        },

        ltrim: function(str, characters){
            characters = defaultToWhiteSpace(characters);
            return str.replace(new RegExp('\^[' + characters + ']+', 'g'), '');
        },

        rtrim: function(str, characters){
            characters = defaultToWhiteSpace(characters);
            return str.replace(new RegExp('[' + characters + ']+$', 'g'), '');
        },

        truncate: function(str, length, truncateStr){
            truncateStr = truncateStr || '...';
            return str.slice(0,length) + truncateStr;
        },

        /**
         * Credits for this function goes to
         * http://www.diveintojavascript.com/projects/sprintf-for-javascript
         *
         * Copyright (c) Alexandru Marasteanu <alexaholic [at) gmail (dot] com>
         * All rights reserved.
         * */
        sprintf: function(){

            var i = 0, a, f = arguments[i++], o = [], m, p, c, x, s = '';
            while (f) {
                if (m = /^[^\x25]+/.exec(f)) {
                    o.push(m[0]);
                }
                else if (m = /^\x25{2}/.exec(f)) {
                    o.push('%');
                }
                else if (m = /^\x25(?:(\d+)\$)?(\+)?(0|'[^$])?(-)?(\d+)?(?:\.(\d+))?([b-fosuxX])/.exec(f)) {
                    if (((a = arguments[m[1] || i++]) == null) || (a == undefined)) {
                        throw('Too few arguments.');
                    }
                    if (/[^s]/.test(m[7]) && (typeof(a) != 'number')) {
                        throw('Expecting number but found ' + typeof(a));
                    }
                    switch (m[7]) {
                        case 'b': a = a.toString(2); break;
                        case 'c': a = String.fromCharCode(a); break;
                        case 'd': a = parseInt(a); break;
                        case 'e': a = m[6] ? a.toExponential(m[6]) : a.toExponential(); break;
                        case 'f': a = m[6] ? parseFloat(a).toFixed(m[6]) : parseFloat(a); break;
                        case 'o': a = a.toString(8); break;
                        case 's': a = ((a = String(a)) && m[6] ? a.substring(0, m[6]) : a); break;
                        case 'u': a = Math.abs(a); break;
                        case 'x': a = a.toString(16); break;
                        case 'X': a = a.toString(16).toUpperCase(); break;
                    }
                    a = (/[def]/.test(m[7]) && m[2] && a >= 0 ? '+'+ a : a);
                    c = m[3] ? m[3] == '0' ? '0' : m[3].charAt(1) : ' ';
                    x = m[5] - String(a).length - s.length;
                    p = m[5] ? str_repeat(c, x) : '';
                    o.push(s + (m[4] ? a + p : p + a));
                }
                else {
                    throw('Huh ?!');
                }
                f = f.substring(m[0].length);
            }
            return o.join('');
        }
    }

    // Aliases

    _s.strip      = _s.trim;
    _s.lstrip     = _s.ltrim;
    _s.rstrip     = _s.rtrim;
    _s.includes   = _s.contains;

    // CommonJS module is defined
    if (typeof window === 'undefined' && typeof module !== 'undefined') {
        // Export module
        module.exports = _s;

    // Integrate with Underscore.js
    } else if (typeof root._ !== 'undefined') {
        root._.mixin(_s);

    // Or define it
    } else {
        root._ = _s;
    }

}());
//      index.js
//
//      Copyright 2010 dvv <dronnikov@gmail.com>
//
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version.
//
//      This program is distributed in the hope that it will be useful,
//      but WITHOUT ANY WARRANTY; without even the implied warranty of
//      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//      GNU General Public License for more details.
//
//      You should have received a copy of the GNU General Public License
//      along with this program; if not, write to the Free Software
//      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//      MA 02110-1301, USA.

/*
 * Given JSON-schema and data, render an HTML form
 */

// FIXME: IE fails to render deeper than 2 array levels
// FIXME: hardcoded id and some text
// TODO: use Modernizr object to make defaults
function obj2form(schema, data, path, entity, flavor){
	function putAttr(value, attr){
		return value ? attr + '="' + (value === true ? attr : value) + '" ' : '';
	}
	schema || (schema = {});
	// FIXME: way rude
	if (schema.readonly === true || typeof schema.readonly == 'object' && schema.readonly[flavor]) return;
	if (!path) path = 'data';
	var s = [];
	if (schema.type === 'object' || schema.$ref instanceof Object || schema.type === 'array') {
		s.push('<fieldset ' + putAttr(_.T(schema.description||'form'+entity), 'title') + '>');
		if (schema.title)
			s.push('<legend>' + _.T('form'+schema.title) + '</legend>');
		// object
		if (schema.type === 'object' || schema.$ref instanceof Object) {
			if (schema.$ref instanceof Object) {
				schema = schema.$ref;
			}
			// top level object ID
			var schema = schema.properties;
			for (var name in schema) if (schema.hasOwnProperty(name)) { var def = schema[name];
				s.push(obj2form(def, data && data[name], path ? path+'['+name+']' : name, entity, flavor));
			}
		// array: provide sort/add/delete
		} else {
			var def = schema.items[0] || schema.items;
			s.push('<ol class="array" rel="'+path+'">'); // TODO: apply dragsort by .array-item
			// fill array items, or just put an empty item
			var array = data || [undefined];
			for (var i = 0; i < array.length; ++i) {
				s.push('<li class="array-item">');
				s.push(obj2form(def, array[i], path+'[]', entity, flavor));
				// add/delete
				// TODO: configurable text
				s.push('<div class="array-action">');
				s.push('<a class="array-action" rel="clone" href="#">'+_.T('formArrayClone')+'</a>');
				s.push('<a class="array-action" rel="remove" href="#">'+_.T('formArrayRemove')+'</a>');
				s.push('<a class="array-action" rel="moveup" href="#">'+_.T('formArrayMoveUp')+'</a>');
				s.push('<a class="array-action" rel="movedown" href="#">'+_.T('formArrayMoveDown')+'</a>');
				s.push('</div>');
				s.push('</li>');
			}
			s.push('</ol>');
		}
		s.push('</fieldset>');
	} else {
		s.push('<div class="field">');
		var label = 'form'+entity+(path.replace('data','').replace(/\[(\w*)\]/g, function(hz, x){return x ? _.capitalize(x) : ''}));
		s.push('<label>' + _.T(label) + '</label>');
		var t, type = 'text';
		var pattern = schema.pattern;
		if ((t = schema.type) === 'number' || t === 'integer') {
			//type = 'number'; // N.B. so far type = 'number' sucks in chrome for linux!
			// N.B. we can't impose a stricter (no dots and exponent) pattern on integers, since 1.1e2 === 110
		} else if (t === 'date' || t === 'string' && schema.format === 'datetime') {
			// TODO: Date or String?!!!
			type = 'isodate';
			//data = Date.fromDB(data);
		//} else if (t === 'boolean') {
		//	type = 'checkbox';
		} else if (schema.format === 'email' || schema.format === 'url' || schema.format === 'password') {
			type = schema.format;
			if (type === 'password') data = undefined;
		}
		// lookup field?
		if (schema.format && schema.format.indexOf('@') >= 0 && path !== 'data[id]') {
			s.push('<div class="combo" id="' + path + '" rel="' + schema.format + '" ' +
				putAttr(data ? _.escapeHTML(data) : data, 'value') +
			'></div>');
		// enum?
		} else if (schema['enum']) {
			if (schema.format === 'tag') {
				//putAttr(schema.format, schema.format === 'tag' ? 'data-tags') +
			} else {
				s.push('<select type="' + type + '" data-type="' + type + '" name="' + path + '">');
				// TODO: lazy fetch from DB?
				var options = schema['enum'];
				//if (schema.$ref)
				s.push('<option></option>'); // null option
				// TODO: value of option?
				//for (var i in options) if (options.hasOwnProperty(i)) { var option = options[i];
				$.each(options, function(index, option){
					var value = option && option.id || option;
					var title = option && option.name || option;
					//s.push('<option value="' + i + '" ' + putAttr(data === i, 'selected') + '>' + option + '</option>');
					console.log('OPTION', data, value, title);
					s.push('<option ' + putAttr(data === value, 'selected') + '>' + title + '</option>');
				});
				s.push('</select>');
			}
		} else if (t === 'string' && (schema.format === 'html' || schema.format === 'js')) {
			// put textarea
			// TODO: required
			s.push('<textarea name="' + path + '" data-format="' + schema.format + '">');
			s.push(data ? _.escapeHTML(data) : data);
			s.push('</textarea>');
		} else if (t === 'boolean') {
			s.push('<select data-type="' + type + '" name="' + path + '">');
			s.push('<option value=""></option>'); // null option
			s.push('<option value="true"' + (data === true ? ' selected="selected"' : '') + '>' + _.T('yes') + '</option>');
			s.push('<option value="false"' + (data === false ? ' selected="selected"' : '') + '>' + _.T('no') + '</option>');
			s.push('</select>');
		} else {
			// put input
			//// date means datetime-local
			s.push('<input type="' + (type === 'date' ? 'datetime-local' : type) + '" data-type="' + type + '" name="' + path + '" ' +
			//s.push('<input type="' + (type === 'date' ? 'text' : type) + '" data-type="' + type + '" name="' + path + '" ' +
			//s.push('<input type="' + type + '" data-type="' + type + '" name="' + path + '" ' +
				putAttr(data && path === 'data[id]', 'readonly') +
				putAttr(schema.description, 'title') +
				putAttr(_.T(label + 'Placeholder'), 'placeholder') +
				//putAttr(schema.optional !== true, 'required') +
				putAttr(schema.minLength, 'minlength') +
				putAttr(schema.maxLength, 'maxlength') +
				putAttr(pattern, 'pattern') +
				putAttr(schema.minimum, 'min') +
				putAttr(schema.maximum, 'max') +
				// checkboxes are controlled via .checked, not value
				// dates also quirky
				//putAttr(data, type === 'checkbox' ? 'checked' : (type === 'date' ? 'data-value' : 'value')) +
				putAttr(data ? _.escapeHTML(data) : data, type === 'checkbox' ? 'checked' : 'value') +
			'/>');
		}
		s.push('</div>');
	}
	return s.join('');
}

/*
 * Power up dynamic form arrays
 *
 * To be called from $(document).ready(...)
 */
function initFormArrays(){
	$(document).delegate('form .array-action', 'click', function(e){
		e.preventDefault();
		var action = $(this).attr('rel');
		var p = $(this).parents('.array-item').first();
		var array = p.parents('.array').first();
		if (action === 'clone') {
			// clone the parent
			var c = p.clone(true); // N.B. we clone event handlers also
			p.after(c);
		} else if (action === 'remove') {
			// remove the parent
			if (p.siblings('.array-item').length) {
				p.remove();
			}
		} else if (action === 'moveup') {
			// move upper
			var c = p.prev('.array-item');
			if (c.length)
				c.before(p.detach());
		} else if (action === 'movedown') {
			// move lower
			var c = p.next('.array-item');
			if (c.length)
				c.after(p.detach());
		}
	});
}

/*
 * Power up dynamic tag suggests
 *
 * To be called from $(document).ready(...)
 */
function initTagSuggests(){
	//$('form input[type=text]').tagSuggest({tags: ['a', 'vv', 'bbb']});
	$('form input[type=text]').autocomplete(['a', 'vv', 'bbb'], {
		matchContains: true,
		minChars: 0,
		multiple: true,
		mustMatch: true,
		autoFill: true
	});
}

/*
 * Get the data object from the specified HTML form
 */
(function($){
	$.fn.serializeObject = function(options){
		options = $.extend({
			filterEmpty: false
		}, options || {});
		var o = {};
		var a = this.serializeArray();
		for (i = 0; i < a.length; i += 1) {
			if (a[i].value !== '' || !options.filterEmpty) {
				o = parseNestedParam(o, a[i].name, a[i].value);
			}
		}
		return o;
	};
	function parseValue(value) {
		value = unescape(value);
		if (value === "true") {
			return true;
		} else if (value === "false") {
			return false;
		} else {
			return value;
		}
	};
	function parseNestedParam(params, field_name, field_value) {
		var match, name, rest;

		if (field_name.match(/^[^\[]+$/)) {
			// basic value
			params[field_name] = parseValue(field_value);
		} else if (match = field_name.match(/^([^\[]+)\[\](.*)$/)) {
			// array
			name = match[1];
			rest = match[2];

			if(params[name] && !$.isArray(params[name])) { throw('400 Bad Request'); }

			if (rest) {
				// array is not at the end of the parameter string
				match = rest.match(/^\[([^\]]+)\](.*)$/);
				if(!match) { throw('400 Bad Request'); }

				if (params[name]) {
					if(params[name][params[name].length - 1][match[1]]) {
						params[name].push(parseNestedParam({}, match[1] + match[2], field_value));
					} else {
						$.extend(true, params[name][params[name].length - 1], parseNestedParam({}, match[1] + match[2], field_value));
					}
				} else {
					params[name] = [parseNestedParam({}, match[1] + match[2], field_value)];
				}
			} else {
				// array is at the end of the parameter string
				if (params[name]) {
					params[name].push(parseValue(field_value));
				} else {
					params[name] = [parseValue(field_value)];
				}
			}
		} else if (match = field_name.match(/^([^\[]+)\[([^\[]+)\](.*)$/)) {
			// hash
			name = match[1];
			rest = match[2] + match[3];

			if (params[name] && $.isArray(params[name])) { throw('400 Bad Request'); }

			if (params[name]) {
				$.extend(true, params[name], parseNestedParam(params[name], rest, field_value));
			} else {
				params[name] = parseNestedParam({}, rest, field_value);
			}
		}
		return params;
	};
})(jQuery);
