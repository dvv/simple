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

*/var htmlparser, http, parseLocation, parseText, parseUrl;
http = require('http');
parseUrl = require('url').parse;
htmlparser = require('htmlparser');
parseText = function(data, next) {
  var handler, parser;
  handler = new htmlparser.DefaultHandler(function(err, dom) {
    return next(err, dom);
  }, {
    ignoreWhitespace: true,
    verbose: false
  });
  parser = new htmlparser.Parser(handler);
  return parser.parseComplete(data);
};
parseLocation = function(url, next) {
  var handler, parser, proxy, req, wget;
  req = parseUrl(url);
  req = {
    host: req.hostname,
    port: req.port || 80,
    path: req.pathname + (req.search ? req.search : ''),
    headers: {
      accept: '*/*',
      'user-agent': 'wget 1.14'
    }
  };
  if (process.env.http_proxy) {
    proxy = parseUrl(process.env.http_proxy);
    req.headers.host = req.host;
    req.port = proxy.port || 80;
    req.host = proxy.hostname;
    req.path = url;
  }
  handler = new htmlparser.DefaultHandler(function(err, dom) {
    return next(err, dom);
  }, {
    ignoreWhitespace: true,
    verbose: false
  });
  parser = new htmlparser.Parser(handler);
  return wget = http.get(req, function(res) {
    if (res.statusCode > 299) {
      return next(res.statusCode);
    }
    res.on('data', function(data) {
      return parser.parseChunk(data);
    });
    res.on('end', function() {
      return parser.done();
    });
    return res.on('error', function(err) {
      return parser.done();
    });
  });
};
module.exports = {
  parseText: parseText,
  parseLocation: parseLocation
};