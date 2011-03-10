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
});