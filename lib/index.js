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

*/var PermissiveFacet, RestrictiveFacet, sys;
var __slice = Array.prototype.slice;
sys = require('util');
console.log = function() {
  var a, args, _i, _len;
  args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  for (_i = 0, _len = args.length; _i < _len; _i++) {
    a = args[_i];
    console.error(sys.inspect(a, false, 10));
  }
};
global.Next = function() {
  var context, next, steps;
  context = arguments[0], steps = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  next = function(err, result) {
    var fn;
    fn = steps.shift();
    if (fn) {
      try {
        fn.call(context, err, result, next);
      } catch (err) {
        next(err);
      }
    } else {
      if (err) {
        throw err;
      }
    }
  };
  return next();
};
Object.defineProperty(Next, 'nop', {
  value: function() {}
});
global.All = function() {
  var context, next, steps;
  context = arguments[0], steps = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  next = function(err, result) {
    var fn;
    if (err) {
      throw err;
    }
    fn = steps.shift();
    if (fn) {
      try {
        fn.call(context, err, result, next);
      } catch (err) {
        console.log('FATAL: ' + err.stack);
        process.exit(1);
      }
    } else {
      if (err) {
        console.log('FATAL: ' + err.stack);
        process.exit(1);
      }
    }
  };
  return next();
};
global._ = require('underscore');
require('./object');
require('./validate');
require('./rql');
Object.freeze(_);
RestrictiveFacet = function() {
  var expose, obj, plus;
  obj = arguments[0], plus = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  expose = ['schema', 'id', 'query', 'get'];
  if (plus.length) {
    expose = expose.concat(plus);
  }
  return _.proxy(obj, expose);
};
PermissiveFacet = function() {
  var expose, obj, plus;
  obj = arguments[0], plus = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
  expose = ['schema', 'id', 'query', 'get', 'add', 'update', 'remove', 'delete', 'undelete', 'purge'];
  if (plus.length) {
    expose = expose.concat(plus);
  }
  return _.proxy(obj, expose);
};
require('./request');
require('./response');
module.exports = {
  Database: require('./database'),
  RestrictiveFacet: RestrictiveFacet,
  PermissiveFacet: PermissiveFacet,
  run: require('./server'),
  stack: require('stack'),
  handlers: require('./handlers')
};