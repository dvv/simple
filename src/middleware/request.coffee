'use strict'

###
 *
 * Simple
 * Copyright(c) 2011 Vladimir Dronnikov <dronnikov@gmail.com>
 * MIT Licensed
 *
###

#
# Request helpers
#

http = require 'http'
parseUrl = require('url').parse
path = require 'path'

REGEXP_IP = /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}$/

http.IncomingMessage::parse = () ->

	# parse URL
	@url = path.normalize @url
	@location = parseUrl @url, false #true
	@params = {} #@location.query or {}

	# N.B. from now on querystring is stripped from the leading "?"
	@location.search = @location.search?.substring 1

	# real remote IP (e.g. if nginx or haproxy as a reverse-proxy is used)
	# FIXME: easily spoofed!
	if s = @headers['x-forwarded-for']
		@socket.remoteAddress = s if REGEXP_IP.test s
		delete @headers['x-forwarded-for']

	# honor X-HTTP-Method-Override
	if @headers['x-http-method-override']
		@method = @headers['x-http-method-override']

	# sanitize headers and method
	# TODO: referer <-> referrer
	headers = @headers
	method = @method = @method.toUpperCase()

	# set security flags
	@xhr = headers['x-requested-with'] is 'XMLHttpRequest'
	if not (@xhr or /application\/j/.test(headers.accept) or
			(method is 'POST' and headers.referer?.indexOf(headers.host + '/') > 0) or
			(method isnt 'GET' and method isnt 'POST'))
		@csrf = true

	@
