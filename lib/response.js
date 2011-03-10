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

*/var fs, http, lookupMimeType;
fs = require('fs');
http = require('http');
lookupMimeType = require('simple-mime')('application/octet-stream');
http.ServerResponse.prototype.send = function(body, headers, status) {
  var k, mime, t, v, _ref, _ref2;
  if (typeof headers === 'number') {
    status = headers;
    headers = null;
  }
  headers != null ? headers : headers = {};
  (_ref = this.headers) != null ? _ref : this.headers = {};
  if (body instanceof Error) {
    if (body instanceof URIError) {
      status = 400;
      body = body.message;
    } else if (body instanceof TypeError) {
      body = 403;
    } else if (body instanceof SyntaxError) {
      status = 406;
      body = body.message;
    } else {
      status = body.status || 500;
      if (status === 500) {
        body = process.errorHandler(body);
      }
      delete body.stack;
      delete body.message;
      delete body.status;
    }
  } else if (body === true) {
    body = 204;
  } else if (body === false) {
    body = 406;
  } else if (body === null) {
    body = 404;
  }
  if (!body) {
    status != null ? status : status = 204;
  } else if ((t = typeof body) === 'number') {
    status = body;
    if (body < 300) {
      if (!this.headers['content-type']) {
        this.contentType('.json');
      }
      body = '{}';
    } else {
      if (!this.headers['content-type']) {
        this.contentType('.txt');
      }
      body = http.STATUS_CODES[status];
    }
  } else if (t === 'string') {
    if (!this.headers['content-type']) {
      this.contentType('.html');
    }
  } else if (t === 'object' || body instanceof Array) {
    if (body.body || body.headers || body.status) {
      if (body.headers) {
        this.headers = body.headers;
      }
      if (body.status) {
        status = body.status;
      }
      body = body.body || '';
      return this.send(body, status);
    } else if (body instanceof Buffer) {
      if (!this.headers['content-type']) {
        this.contentType('.bin');
      }
    } else {
      if (!this.headers['content-type']) {
        this.contentType('.json');
        try {
          if (body instanceof Array && body.totalCount) {
            this.headers['content-range'] = 'items=' + body.start + '-' + body.end + '/' + body.totalCount;
          }
          body = JSON.stringify(body);
          if ((_ref2 = this.req.query) != null ? _ref2.callback : void 0) {
            body = this.req.query.callback.replace(/[^\w$.]/g, '') + '(' + body + ');';
          }
        } catch (err) {
          console.log(err);
          body = 'HZ';
        }
      } else {
        mime = this.headers['content-type'];
        body = serialize(body, mime);
      }
    }
  } else if (typeof body === 'function') {
    if (!this.headers['content-type']) {
      this.contentType('.js');
    }
    body = body.toString();
  } else {
    console.log('BODY!!!', t, body);
    if (!this.headers['content-length']) {
      this.headers['content-length'] = (body instanceof Buffer ? body.length : Buffer.byteLength(body));
    }
  }
  for (k in headers) {
    v = headers[k];
    this.headers[k] = v;
  }
  this.writeHead(status || 200, this.headers);
  return this.end(body);
};
http.ServerResponse.prototype.contentType = function(type) {
  return this.headers['content-type'] = lookupMimeType(type);
};
http.ServerResponse.prototype.redirect = function(url, status) {
  return this.send('', {
    location: url
  }, status || 302);
};
http.ServerResponse.prototype.attachment = function(filename) {
  this.headers['content-disposition'] = filename ? 'attachment; filename="' + path.basename(filename) + '"' : 'attachment';
  return this;
};