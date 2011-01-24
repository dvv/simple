'use strict'

#
# Request helpers
#

http = require 'http'
parseUrl = require('url').parse
formidable = require 'formidable'

http.IncomingMessage::parse = () ->

	# parse URL
	# N.B. we prohibit /../
	path = @url
	while lastPath isnt path
		lastPath = path
		path = path.replace /\/[^\/]*\/\.\.\//, '/'
	@location = parseUrl path, true

	# N.B. from now on querystring is stripped from the leading "?"
	@location.search = @location.search?.substring 1

	# real remote IP (e.g. if nginx or haproxy as a reverse-proxy is used)
	# FIXME: easily spoofed!
	if @headers['x-forwarded-for']
		@socket.remoteAddress = @headers['x-forwarded-for']
		delete @headers['x-forwarded-for']

	# honor X-HTTP-Method-Override
	if @headers['x-http-method-override']
		@method = @headers['x-http-method-override'].toUpperCase()

	# parse URL parameters
	@params = @location.query or {}

	# sanitize headers and method
	headers = @headers
	method = @method = @method.toUpperCase()

	# set security flags
	@xhr = headers['x-requested-with'] is 'XMLHttpRequest'
	if not (@xhr or /application\/j/.test(headers.accept) or
			(method is 'POST' and headers.referer?.indexOf(headers.host + '/') > 0) or
			(method isnt 'GET' and method isnt 'POST'))
		@csrf = true

	@

http.IncomingMessage::parseBody = (next) ->

	self = @
	self.params = {} # N.B. drop any parameter got from querystring
	# deserialize
	form = new formidable.IncomingForm()
	form.uploadDir = 'upload'
	form.on 'file', (field, file) ->
		form.emit 'field', field, file
	form.on 'field', (field, value) ->
		#console.log 'FIELD', field, value
		if not self.params[field]
			self.params[field] = value
		else if self.params[field] not instanceof Array
			self.params[field] = [self.params[field], value]
		else
			self.params[field].push value
	form.on 'error', (err) ->
		#console.log 'TYPE?', err
		next SyntaxError(err.message or err)
	form.on 'end', () ->
		# Backbone.emulateJSON compat:
		# if 'application/x-www-form-urlencoded[; foobar]' --> reparse 'model' key to be the final params
		if self.headers['content-type'].split(';')[0] is 'application/x-www-form-urlencoded'
			delete self.params._method
			#console.log 'BACKBONE?', self.params
			self.params = JSON.parse(self.params.model || '{}')
		next null
	form.parse @
