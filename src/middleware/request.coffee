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
	headers = @headers
	method = @method = @method.toUpperCase()

	# set security flags
	@xhr = headers['x-requested-with'] is 'XMLHttpRequest'
	if not (@xhr or /application\/j/.test(headers.accept) or
			(method is 'POST' and headers.referer?.indexOf(headers.host + '/') > 0) or
			(method isnt 'GET' and method isnt 'POST'))
		@csrf = true

	@
