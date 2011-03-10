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

*/var REGEXP_IP, http, parseUrl, path;
http = require('http');
parseUrl = require('url').parse;
path = require('path');
REGEXP_IP = /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$/;
http.IncomingMessage.prototype.parse = function() {
  var headers, method, s, _ref, _ref2;
  this.url = path.normalize(this.url);
  this.location = parseUrl(this.url, true);
  this.location.search = (_ref = this.location.search) != null ? _ref.substring(1) : void 0;
  if (s = this.headers['x-forwarded-for']) {
    if (REGEXP_IP.test(s)) {
      this.socket.remoteAddress = s;
    }
    delete this.headers['x-forwarded-for'];
  }
  if (this.headers['x-http-method-override']) {
    this.method = this.headers['x-http-method-override'].toUpperCase();
  }
  this.params = this.location.query || {};
  headers = this.headers;
  method = this.method = this.method.toUpperCase();
  this.xhr = headers['x-requested-with'] === 'XMLHttpRequest';
  if (!(this.xhr || /application\/j/.test(headers.accept) || (method === 'POST' && ((_ref2 = headers.referer) != null ? _ref2.indexOf(headers.host + '/') : void 0) > 0) || (method !== 'GET' && method !== 'POST'))) {
    this.csrf = true;
  }
  return this;
};