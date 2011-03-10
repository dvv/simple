'use strict';
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
    value = value != null ? '' + value : '';
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
});