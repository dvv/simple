'use strict'

#
# Request helpers
#

http = require 'http'
parseUrl = require('url').parse

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
