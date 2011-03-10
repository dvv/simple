/*
taken from dvv/stack.static
*/var Crypto, Fs, Mime, Path, Util, build_etag, cache, cacheInvalid, etag_matches, exports, methods, not_modified, parse_range, stats;
Util = require('util');
Path = require('path');
Fs = require('fs');
Crypto = require('crypto');
Mime = require('simple-mime')('application/octet-stream');
methods = ['GET', 'HEAD'];
cacheInvalid = false;
stats = {};
cache = {};
exports = module.exports = function(root, options) {
  var defaultFile, headers, key, value, _ref, _ref2, _ref3;
  if (options == null) {
    options = {};
  }
  root = Path.normalize(root);
  defaultFile = options["default"];
  if (options.etag == null) {
    options.etag = exports.etag;
  }
  headers = {};
  (_ref = options.headers) != null ? _ref : options.headers = {};
  _ref2 = exports.defaultHeaders;
  for (key in _ref2) {
    value = _ref2[key];
    headers[key] = value;
  }
  if (options.headers) {
    _ref3 = options.headers;
    for (key in _ref3) {
      value = _ref3[key];
      headers[key] = value;
    }
  }
  return function(req, res, next) {
    if (req.url.match(/\.\.\//)) {
      return next();
    }
    if (methods.indexOf(req.method) === -1) {
      res.writeHead(405, {
        accept: 'GET, HEAD'
      });
      return res.end();
    }
    if (defaultFile && req.url.match(/\/$/)) {
      req.url = "" + req.url + defaultFile;
    }
    options.headers = headers;
    options.file = "" + root + req.url;
    return exports.serve(req, res, options, function(err) {
      if (err) {
        return next();
      }
    });
  };
};
exports.defaultHeaders = {};
exports.serve = function(req, res, options, next) {
  var cached, file, stat;
  if (options == null) {
    options = {};
  }
  file = options.file;
  if (stats.hasOwnProperty(file)) {
    stat = stats[file];
    if (stat instanceof Error) {
      next(stat);
    } else if (cache.hasOwnProperty(file)) {
      cached = cache[file];
      exports.writeHead(req, res, file, stat, options, function(status, fs_options) {
        if (((199 < status && status < 299)) && req.method === 'GET') {
          if (stat.size > options.cacheMaxFileSizeToCache) {
            Util.pump(Fs.createReadStream(file, fs_options), res, next);
          } else {
            res.end((fs_options.start != null) || (fs_options.end != null) ? cached.slice(fs_options.start, fs_options.end) : cached);
          }
        } else {
          res.end();
        }
      });
    } else {
      Fs.readFile(file, function(err, data) {
        if (err) {
          next(err);
        } else {
          cache[file] = data;
          exports.serve(req, res, options, next);
        }
      });
    }
  } else {
    Fs.stat(file, function(err, result) {
      stats[file] = err || result;
      if (err) {
        next(err);
      } else {
        exports.serve(req, res, options, next);
      }
    });
  }
};
exports.writeHead = function(req, res, file, stats, options, cb) {
  var fs_options, headers, ifmod, ifunmod, range, since, status;
  if (options == null) {
    options = {};
  }
  fs_options = {};
  headers = exports.buildHeaders(options.headers, file, stats);
  status = options.status || 200;
  ifmod = req.headers['if-modified-since'];
  if (ifmod) {
    since = Date.parse(ifmod);
    if (since && since > stats.mtime.getTime()) {
      return not_modified(res, headers, cb);
    }
  }
  ifunmod = req.headers['if-unmodified-since'];
  if (ifunmod) {
    since = Date.parse(ifunmod);
    if (since && since < stats.mtime.getTime()) {
      headers['content-length'] = 0;
      res.writeHead(412, headers);
      return cb(412);
    }
  }
  headers.etag = build_etag(file, stats);
  if (etag_matches(req.headers['if-none-match'], headers.etag)) {
    return not_modified(res, headers, cb);
  }
  range = parse_range(stats, req.headers.range);
  if (range) {
    status = 206;
    headers['content-length'] = range.length;
    headers['content-range'] = "bytes " + range.start + "-" + range.end + "/" + stats.size;
    fs_options.start = range.start;
    fs_options.end = range.end;
  }
  res.writeHead(status, headers);
  return cb(status, fs_options);
};
exports.buildHeaders = function(headers, file, stats) {
  headers['content-type'] = Mime(file);
  headers['content-length'] = stats.size;
  headers['last-modified'] = stats.mtime.toUTCString();
  return headers;
};
build_etag = function(file, stats) {
  var hash;
  hash = Crypto.createHash('sha1');
  hash.update(file);
  hash.update(stats.size);
  hash.update(stats.mtime);
  return "\"" + (hash.digest('hex')) + "\"";
};
parse_range = function(stats, header) {
  var match, range;
  if (!header) {
    return;
  }
  match = header.match(/^(bytes=)?(\d*)-(\d*)$/);
  if (!match) {
    return;
  }
  range = {};
  if (match[2]) {
    range.start = parseInt(match[2]);
  }
  range.end = match[3] ? parseInt(match[3]) : stats.size;
  if (!range.start) {
    range.start = stats.size - range.end;
    range.end = stats.size;
  }
  range.length = range.end - range.start + 1;
  if (range.start > range.end) {
    return null;
  }
  return range;
};
not_modified = function(res, headers, cb) {
  headers['content-length'] = 0;
  res.writeHead(304, headers);
  return cb(304);
};
etag_matches = function(request_etag, file_etag) {
  return (request_etag != null) && (file_etag != null) && request_etag === file_etag;
};