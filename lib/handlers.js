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

*/module.exports.body = function(options) {
  var formidable, handler;
  if (options == null) {
    options = {};
  }
  formidable = require('formidable');
  return handler = function(req, res, next) {
    var form;
    if (req.method === 'POST' || req.method === 'PUT') {
      console.log('DESER');
      req.params = {};
      form = new formidable.IncomingForm();
      form.uploadDir = options.uploadDir || 'upload';
      form.on('file', function(field, file) {
        return form.emit('field', field, file);
      });
      form.on('field', function(field, value) {
        console.log('FIELD', field, value);
        if (!req.params[field]) {
          return req.params[field] = value;
        } else if (!Array.isArray(req.params[field])) {
          return req.params[field] = [req.params[field], value];
        } else {
          return req.params[field].push(value);
        }
      });
      form.on('error', function(err) {
        console.log('TYPE?', err);
        return next(SyntaxError(err.message || err));
      });
      form.on('end', function() {
        console.log('END');
        if (req.headers['content-type'].split(';')[0] === 'application/x-www-form-urlencoded') {
          delete req.params._method;
          req.params = JSON.parse(req.params.model || '{}');
        }
        return next();
      });
      return form.parse(req);
    } else {
      return next();
    }
  };
};
module.exports.jsonBody = function(options) {
  if (options == null) {
    options = {};
  }
  return function(req, res, next) {
    var body, _ref;
    req.parse();
    res.req = req;
    (_ref = res.headers) != null ? _ref : res.headers = {};
    if ((req.method === 'POST' || req.method === 'PUT') && req.headers['content-type'].split(';')[0] === 'application/json') {
      req.params = {};
      body = '';
      req.on('data', function(chunk) {
        var _ref;
        body += chunk.toString('utf8');
        if ((body.length > (_ref = options.maxLength) && _ref > 0)) {
          req.params = 'Length exceeded';
          return next();
        }
      });
      return req.on('end', function() {
        try {
          req.params = JSON.parse(body);
        } catch (err) {
          req.params = err.message;
        }
        return next();
      });
    } else {
      return next();
    }
  };
};
module.exports.logRequest = function(options) {
  var handler;
  return handler = function(req, res, next) {
    console.log("REQUEST " + req.method + " " + req.url, req.params);
    return next();
  };
};
module.exports.logResponse = function(options) {
  var handler;
  return handler = function(req, res, next) {
    console.log("RESPONSE", 'NYI');
    return next();
  };
};
module.exports.authCookie = function(options) {
  var Cookie, cache, cookie, getContext;
  if (options == null) {
    options = {};
  }
  Cookie = require('./cookie');
  cookie = options.cookie || 'uid';
  getContext = options.getContext;
  if (getContext) {
    require('http').ServerResponse.prototype.setSession = function(session) {
      var cookieOptions;
      cookieOptions = {
        path: '/'
      };
      if (_.isObject(session)) {
        if (session.expires) {
          cookieOptions.expires = session.expires;
        }
        this.req.cookie.set(cookie, session.uid, cookieOptions);
        return;
      } else {
        this.req.cookie.clear(cookie, cookieOptions);
        return session;
      }
    };
    cache = {};
    return function(req, res, next) {
      var uid;
      req.cookie = new Cookie(req, res, options.secret);
      uid = req.cookie.get(cookie) || '';
      if (cache.hasOwnProperty(uid)) {
        req.context = cache[uid];
        return next();
      } else {
        return getContext(uid, function(err, context) {
          cache[uid] = req.context = context || {
            user: {}
          };
          return next();
        });
      }
    };
  } else {
    return function(req, res, next) {
      req.context = {
        user: {}
      };
      return next();
    };
  }
};
module.exports.jsonrpc = function(options) {
  if (options == null) {
    options = {};
  }
  return function(req, res, next) {
    return Next({}, function(xxx, yyy, step) {
      var args, call, context, data, fn, method, parts, query, search;
      if (_.isString(req.params)) {
        return step(req.params);
      }
      search = decodeURI(req.location.search || '');
      query = _.rql(search);
      if (query.error) {
        return step(query.error);
      }
      method = req.method;
      parts = _.map(req.location.pathname.substring(1).split('/'), function(x) {
        return decodeURIComponent(x);
      });
      data = req.params;
      context = req.context;
      if (method === 'GET') {
        call = {
          jsonrpc: '2.0',
          method: 'query',
          params: [query]
        };
        if (parts[1]) {
          call.method = 'get';
          call.params = [parts[1]];
        }
      } else if (method === 'PUT') {
        call = {
          jsonrpc: '2.0',
          method: 'update',
          params: [query, data]
        };
        if (parts[1]) {
          call.params = [[parts[1]], data];
        }
      } else if (method === 'POST') {
        if (data.jsonrpc) {
          call = data;
        } else {
          call = {
            jsonrpc: '2.0',
            method: 'add',
            params: [data]
          };
        }
      } else if (method === 'DELETE') {
        call = {
          jsonrpc: '2.0',
          method: 'remove',
          params: [query]
        };
        if (parts[1]) {
          call.params = [[parts[1]]];
        }
      } else {
        return next();
      }
      if (parts[0] !== '') {
        call.method = call.method ? [parts[0], call.method] : [parts[0]];
      }
      fn = _.get(context, call.method);
      if (fn) {
        args = Array.isArray(call.params) ? call.params : call.params ? [call.params] : [];
        args.unshift(context);
        args.push(step);
        console.log('CALLING', args, fn.length);
        if (args.length !== fn.length) {
          return step(406);
        }
        return fn.apply(null, args);
      } else {
        if (call.method === 'login' && context.verify) {
          return context.verify(call.params, function(err, session) {
            return step(res.setSession(err || session));
          });
        } else {
          return next();
        }
      }
    }, function(err, result) {
      var response;
      response = {
        jsonrpc: '2.0'
      };
      if (err) {
        response.error = err.message || err;
      } else if (result === void 0) {
        response.result = true;
      } else {
        response.result = result;
      }
      return res.send(response);
    });
  };
};
module.exports.mount = function(method, path, handler) {
  if (handler) {
    return function(req, res, next) {
      if (req.method === method && req.location.pathname === path) {
        return handler(req, res, next);
      } else {
        return next();
      }
    };
  } else {
    handler = path;
    path = method;
    return function(req, res, next) {
      var fn;
      if (req.location.pathname === path && (fn = handler[req.method.toLowerCase()])) {
        return fn(req, res, next);
      } else {
        return next();
      }
    };
  }
};
module.exports.static = function(options) {
  var _ref, _ref2;
  if (options == null) {
    options = {};
  }
  (_ref = options.root) != null ? _ref : options.root = 'public';
  (_ref2 = options["default"]) != null ? _ref2 : options["default"] = 'index.html';
  require('simple-mime');
  return require('./static')(options.root, options);
};
module.exports.dynamic = function(options) {
  var cache, fs, handler, tmplSyntax;
  if (options == null) {
    options = {};
  }
  fs = require('fs');
  tmplSyntax = options.syntax || {
    evaluate: /\{\{([\s\S]+?)\}\}/g,
    interpolate: /\$\$\{([\s\S]+?)\}/g,
    escape: /\$\{([\s\S]+?)\}/g
  };
  cache = {};
  return handler = function(req, res, next) {
    var file;
    if (req.method === 'GET' && (file = options.map[req.location.pathname])) {
      if (cache.hasOwnProperty(file)) {
        res.send(cache[file](req.context));
      } else {
        fs.readFile(file, function(err, html) {
          if (err) {
            return next(err);
          }
          cache[file] = _.template(html.toString('utf8'), null, tmplSyntax);
          handler(req, res, next);
        });
      }
    } else {
      next();
    }
  };
};
module.exports.getRemoteUserInfo = function(options) {
  var getInfo, handler;
  if (options == null) {
    options = {};
  }
  getInfo = require('./helpers').getRemoteUserInfo(options);
  return handler = function(req, res, next) {
    req.info = getInfo(req);
    next();
  };
};