'use strict'

###

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

###

#
# Response additions
#

fs = require 'fs'
http = require 'http'
lookupMimeType = require('simple-mime') 'application/octet-stream'

http.ServerResponse::send = (body, headers, status) ->

	#console.log 'RESPONSE', body
	# allow status as second arg
	if typeof headers is 'number'
		status = headers
		headers = null
	# defaults
	headers ?= {}
	@headers ?= {}
	# determine content type
	if body instanceof Error
		# TODO: move to Stack.errorHandler
		if body instanceof URIError
			status = 400
			body = body.message
		else if body instanceof TypeError
			body = 403
		else if body instanceof SyntaxError
			status = 406
			body = body.message
		#else if body instanceof RangeError
		#	body = 405
		else
			status = body.status or 500
			# 500 means server internal failure
			if status is 500
				body = process.errorHandler body
			delete body.stack
			delete body.message
			delete body.status
	else if body is true
		body = 204
	else if body is false
		body = 406
	else if body is null
		body = 404
	if not body
		status ?= 204
	else if (t = typeof body) is 'number'
		status = body
		if body < 300
			@contentType '.json' unless @headers['content-type']
			body = '{}'
		else
			@contentType '.txt' unless @headers['content-type']
			body = http.STATUS_CODES[status]
	else if t is 'string'
		@contentType '.html' unless @headers['content-type']
	else if t is 'object' or body instanceof Array
		if body.body or body.headers or body.status
			@headers = body.headers if body.headers
			status = body.status if body.status
			body = body.body or ''
			return @send body, status
		else if body instanceof Buffer
			@contentType '.bin' unless @headers['content-type']
		else
			if not @headers['content-type']
				@contentType '.json'
				try
					if body instanceof Array and body.totalCount
						@headers['content-range'] = 'items=' + body.start + '-' + body.end + '/' + body.totalCount
					#console.log body
					body = JSON.stringify body
					# JSONP?
					if @req.query?.callback
						body = @req.query.callback.replace(/[^\w$.]/g, '') + '(' + body + ');'
				catch err
					console.log err
					body = 'HZ' #sys.inspect body
			else
				mime = @headers['content-type']
				body = serialize body, mime
	else if typeof body is 'function'
		@contentType '.js' unless @headers['content-type']
		body = body.toString()
	else
		console.log 'BODY!!!', t, body
		# populate content-length:
		@headers['content-length'] = (if body instanceof Buffer then body.length else Buffer.byteLength body) unless @headers['content-length']

	# merge headers passed
	@headers[k] = v for k, v of headers

	# respond
	@writeHead status or 200, @headers
	# TODO: serializer!
	@end body

http.ServerResponse::contentType = (type) ->
	@headers['content-type'] = lookupMimeType type

http.ServerResponse::redirect = (url, status) ->
	@send '', {location: url}, status or 302

http.ServerResponse::attachment = (filename) ->
	@headers['content-disposition'] = if filename then 'attachment; filename="' + path.basename(filename) + '"' else 'attachment'
	@
