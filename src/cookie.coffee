#
# Vladimir Dronnikov 2011 dronnikov@gmail.com
#
# ideas from
#
# https://github.com/jed/cookie-node.git
# https://github.com/jed/cookies.git
# https://github.com/caolan/cookie-sessions.git
#

crypto = require 'crypto'

# regexp helper to extract a named cookie
getCookiePattern = _.memoize (name) ->
	new RegExp('(?:^|;) *' + name.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&') + '=([^;]*)')

class Cookie

	constructor: (@req, @res, @secret) ->
		# by default cookies expire in 15 days
		@expires = -15*24*60*60*1000

	encrypt: (str) ->
		if @secret
			cipher = crypto.createCipher 'aes192', @secret
			cipher.update(str, 'utf8', 'hex') + cipher.final('hex')
		else
			str

	decrypt: (str) ->
		if @secret
			decipher = crypto.createDecipher 'aes192', @secret
			decipher.update(str, 'hex', 'utf8') + decipher.final('utf8')
		else
			str

	sign: (str) ->
		if @secret
			hmac = crypto.createHmac 'sha1', @secret
			hmac.update str
			hmac.digest 'hex'
		else
			str

	set: (name, value, options = {}) ->
		cookie = name + '='
		if value?
			# options.expires suffer usual Date hell
			expires = options.expires or @expires
			if _.isNumber expires
				if expires < 0
					expires = Date.now() - expires
				expires = new Date expires
			else unless _.isDate expires
				expires = _.parseDate expires
			# encrypt and sign the cookie value
			data = @encrypt value
			timestamp = +expires
			cookie += @sign(timestamp + data) + timestamp + data
		else
			expires = new Date 0
		cookie += '; path=' + (options.path or '/')
		cookie += '; expires=' + expires.toUTCString() if expires
		cookie += '; domain=' + options.domain if options.domain
		cookie += '; secure' if options.secure
		cookie += '; httponly' unless options.httpOnly is false
		#return cookie
		header = @res.getHeader 'Set-Cookie'
		if not header
			header = cookie
		else
			if Array.isArray header
				header.push cookie
			else
				header = [header, cookie]
		@res.setHeader 'Set-Cookie', header

	clear: (name, options = {}) ->
		@set name, null, options

	get: (name) ->
		header = @req.headers.cookie
		if header and (match = header.match(getCookiePattern(name))) and (str = match[1])
			if @sign(str.substring(40)) is str.substr(0, 40) and +str.substring(40, 53) > Date.now()
				@decrypt str.substring(53)
			else
				# N.B. we explicitly clear expired cookies
				@clear name
				undefined

module.exports = Cookie
