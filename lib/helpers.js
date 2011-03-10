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

*/var getRemoteUserInfo, template;
template = function(options) {
  var tmplSyntax, types;
  if (options == null) {
    options = {};
  }
  tmplSyntax = options.syntax || {
    evaluate: /\{\{([\s\S]+?)\}\}/g,
    interpolate: /\$\{([\s\S]+?)\}/g
  };
  types = options.extensions || {
    '.html': function(data) {
      return _.template(data.toString('utf8'), null, tmplSyntax);
    }
  };
  return function(data, name) {
    var ext, fn;
    for (ext in types) {
      fn = types[ext];
      if (name.slice(-ext.length) === ext) {
        return fn(data);
      }
    }
    return data;
  };
};
getRemoteUserInfo = function(options) {
  var getLocation, useragent;
  if (options == null) {
    options = {};
  }
  getLocation = require('simple-geoip')(options.fileName).lookupByIP;
  useragent = require('useragent');
  return function(req) {
    var agent, info, ip, _ref;
    ip = req.connection.remoteAddress;
    agent = req.headers['user-agent'] || '';
    return info = {
      ip: ip,
      geo: getLocation(ip, true),
      agent: useragent.parser(agent),
      browser: useragent.browser(agent),
      nls: ((_ref = req.headers['accept-language']) != null ? _ref.replace(/[,;].*$/, '').toLowerCase() : void 0) || 'en-us'
    };
  };
};
module.exports = {
  getRemoteUserInfo: getRemoteUserInfo
};