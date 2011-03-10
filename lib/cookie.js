var Cookie, crypto, getCookiePattern;
crypto = require('crypto');
getCookiePattern = _.memoize(function(name) {
  return new RegExp('(?:^|;) *' + name.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&') + '=([^;]*)');
});
Cookie = (function() {
  function Cookie(req, res, secret) {
    this.req = req;
    this.res = res;
    this.secret = secret;
    this.expires = -15 * 24 * 60 * 60 * 1000;
  }
  Cookie.prototype.encrypt = function(str) {
    var cipher;
    if (this.secret) {
      cipher = crypto.createCipher('aes192', this.secret);
      return cipher.update(str, 'utf8', 'hex') + cipher.final('hex');
    } else {
      return str;
    }
  };
  Cookie.prototype.decrypt = function(str) {
    var decipher;
    if (this.secret) {
      decipher = crypto.createDecipher('aes192', this.secret);
      return decipher.update(str, 'hex', 'utf8') + decipher.final('utf8');
    } else {
      return str;
    }
  };
  Cookie.prototype.sign = function(str) {
    var hmac;
    if (this.secret) {
      hmac = crypto.createHmac('sha1', this.secret);
      hmac.update(str);
      return hmac.digest('hex');
    } else {
      return str;
    }
  };
  Cookie.prototype.set = function(name, value, options) {
    var cookie, data, expires, header, timestamp;
    if (options == null) {
      options = {};
    }
    cookie = name + '=';
    if (value != null) {
      expires = options.expires || this.expires;
      if (_.isNumber(expires)) {
        if (expires < 0) {
          expires = Date.now() - expires;
        }
        expires = new Date(expires);
      } else if (!_.isDate(expires)) {
        expires = _.parseDate(expires);
      }
      data = this.encrypt(value);
      timestamp = +expires;
      cookie += this.sign(timestamp + data) + timestamp + data;
    } else {
      expires = new Date(0);
    }
    cookie += '; path=' + (options.path || '/');
    if (expires) {
      cookie += '; expires=' + expires.toUTCString();
    }
    if (options.domain) {
      cookie += '; domain=' + options.domain;
    }
    if (options.secure) {
      cookie += '; secure';
    }
    if (options.httpOnly !== false) {
      cookie += '; httponly';
    }
    header = this.res.getHeader('Set-Cookie');
    if (!header) {
      header = cookie;
    } else {
      if (Array.isArray(header)) {
        header.push(cookie);
      } else {
        header = [header, cookie];
      }
    }
    return this.res.setHeader('Set-Cookie', header);
  };
  Cookie.prototype.clear = function(name, options) {
    if (options == null) {
      options = {};
    }
    return this.set(name, null, options);
  };
  Cookie.prototype.get = function(name) {
    var header, match, str;
    header = this.req.headers.cookie;
    if (header && (match = header.match(getCookiePattern(name))) && (str = match[1])) {
      if (this.sign(str.substring(40)) === str.substr(0, 40) && +str.substring(40, 53) > Date.now()) {
        return this.decrypt(str.substring(53));
      } else {
        this.clear(name);
        return;
      }
    }
  };
  return Cookie;
})();
module.exports = Cookie;