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
# decode request body
#
module.exports.body = (options = {}) ->

	formidable = require 'formidable'

	handler = (req, res, next) ->

		if req.method is 'POST' or req.method is 'PUT'
			console.log 'DESER'
			req.params = {} # N.B. drop any parameter got from querystring
			# deserialize
			form = new formidable.IncomingForm()
			form.uploadDir = options.uploadDir or 'upload'
			form.on 'file', (field, file) ->
				form.emit 'field', field, file
			form.on 'field', (field, value) ->
				console.log 'FIELD', field, value
				if not req.params[field]
					req.params[field] = value
				else if not Array.isArray req.params[field]
					req.params[field] = [req.params[field], value]
				else
					req.params[field].push value
			form.on 'error', (err) ->
				console.log 'TYPE?', err
				next SyntaxError(err.message or err)
			form.on 'end', () ->
				console.log 'END'
				# Backbone.emulateJSON compat:
				# if 'application/x-www-form-urlencoded[; foobar]' --> reparse 'model' key to be the final params
				if req.headers['content-type'].split(';')[0] is 'application/x-www-form-urlencoded'
					delete req.params._method
					#console.log 'BACKBONE?', req.params
					req.params = JSON.parse(req.params.model or '{}')
				next()
			form.parse req
		else
			next()

#
# decode request JSON body
#
# N.B. to be reliable must be the first in middleware
# consider using pause/resume helpers from express otherwise
#
module.exports.jsonBody = (options = {}) ->

	(req, res, next) ->

		# parse the request, leave body alone
		req.parse()

		# attach request to response
		res.req = req
		res.headers ?= {}

		# N.B. content-type: application/json is required
		if (req.method is 'POST' or req.method is 'PUT') and req.headers['content-type'].split(';')[0] is 'application/json'
			req.params = {}
			body = ''
			req.on 'data', (chunk) ->
				body += chunk.toString 'utf8'
				# fuser not to exhaust memory
				if body.length > options.maxLength > 0
					req.params = 'Length exceeded'
					next()
			req.on 'end', () ->
				try
					# TODO: use kriszyp's more forgiving one?
					req.params = JSON.parse body
				catch err
					req.params = err.message
				next()
		else
			next()

#
# log request and response code
#
# thanks creationix/creationix/log
#
module.exports.log = (options = {}) ->

	handler = (req, res, next) ->
		send = res.send
		res.send = () ->
			console.log "REQUEST #{req.method} #{req.url} " + JSON.stringify(req.params) + " -- RESPONSE " + JSON.stringify(arguments)
			send.apply @, arguments
		next()

#
# fetch secret cookie defining the user, lookup in db
#
module.exports.authCookie = (options = {}) ->

	Cookie = require './cookie'
	cookie = options.cookie or 'uid'
	getContext = options.getContext

	if getContext

		# helper to set/clear secured cookie
		require('http').ServerResponse::setSession = (session) ->
			cookieOptions = path: '/'
			if session and typeof session is 'object'
				# set the cookie
				cookieOptions.expires = session.expires if session.expires
				@req.cookie.set cookie, session.uid, cookieOptions
				undefined
			else
				# clear the cookie
				@req.cookie.clear cookie, cookieOptions
				session

		#
		# contexts cache
		# TODO: how to reset?
		#
		cache = {}

		#
		# handler
		#
		(req, res, next) ->
			req.cookie = new Cookie req, res, options.secret
			# get the user ID
			# N.B. we use '' for all falsy uids
			uid = req.cookie.get(cookie) or ''
			#console.log "UID #{uid}"
			# attach context of that user to the request
			if cache.hasOwnProperty uid
				req.context = cache[uid]
				next()
			else
				getContext uid, (err, context) ->
					# N.B. any error in getting user just means no user
					cache[uid] = req.context = context or user: {}
					#console.log "USER", req.context
					# freeze the context
					Object.freeze context
					next()
			return
	else
		(req, res, next) ->
			# null user
			req.context = user: {}
			next()
			return

#
# perform basic www authentication
#
module.exports.authBasic = (options = {}) ->

	getContext = options.getContext

	if getContext

		realm = options.realm or 'simple'

		# helpers
		unauthorized = (res) ->
			res.setHeader 'WWW-Authenticate', "Basic realm=\"#{realm}\""
			res.send 401
			return

		#
		# contexts cache
		# TODO: how to reset?
		#
		cache = {}

		#
		# handler
		#
		(req, res, next) ->
			auth = req.headers.authorization
			return unauthorized res unless auth
			[scheme, credentials] = auth.split ' '
			return res.send 400 unless scheme is 'Basic'
			[uid, pass] = new Buffer(credentials, 'base64').toString('utf8').split ':'
			console.log "UID #{uid} PASS #{pass}"
			# attach context of that user to the request
			if cache.hasOwnProperty uid
				req.context = cache[uid]
				next()
			else
				getContext {uid: uid, pass: pass}, (err, context) ->
					# N.B. any error in getting user just means no user
					cache[uid] = req.context = context or user: {}
					#console.log "USER", req.context
					# freeze the context
					Object.freeze context
					next()
			return
	else
		(req, res, next) ->
			# null user
			req.context = user: {}
			next()
			return

#
# bind a handler to a location, and optionally HTTP verb
#
module.exports.mount = (method, path, handler) ->

	# 3 parameters -> expect exact match
	if handler
		(req, res, next) ->
			if req.method is method and req.location.pathname is path
				handler req, res, next
			else
				next()

	# 2 or less parameters -> method chooses the key of handler hash
	else
		handler = path
		path = method
		(req, res, next) ->
			if req.location.pathname is path and fn = handler[req.method.toLowerCase()]
				fn req, res, next
			else
				next()

#
# serve pure static content from options.root
#
module.exports.static0 = (options = {}) ->

	options.root ?= 'public'
	options.default ?= 'index.html'

	require('simple-mime')
	require('./static0') options.root, options

#
# serve pure static content from options.root
#
module.exports.static = require './static'

#
# serve dynamic content based on template files using options.map
#
module.exports.dynamic = (options = {}) ->

	fs = require 'fs'
	template = require('underscore').template

	tmplSyntax = options.syntax or {
		evaluate    : /\{\{([\s\S]+?)\}\}/g
		interpolate : /\$\$\{([\s\S]+?)\}/g
		escape      : /\$\{([\s\S]+?)\}/g
	}

	cache = {}

	handler = (req, res, next) ->

		#console.log 'DYNAMIC?', req
		if req.method is 'GET' and file = options.map[req.location.pathname]
			if cache.hasOwnProperty file
				# TODO: disable caching
				# TODO: Content-Length:?
				#console.log 'CACHE', cache[file]
				res.send cache[file] req.context
			else
				fs.readFile file, (err, html) ->
					return next err if err
					cache[file] = template html.toString('utf8'), null, tmplSyntax
					handler req, res, next
					return
		else
			next()
		return

#
# REST/JSON-RPC unified handler
#
module.exports.rest = (options = {}) ->

	convertToRPC = require '../helpers/rest'

	(req, res, next) ->

		data = req.params
		Next req.context or {},
			(err, dummy, step) ->
				# pass parse errors to response
				return step data if typeof data is 'string'
				#
				# parse query. FIXME: do we need it here?
				#
				query = decodeURI(req.location.search or '')
				#console.log 'QUERY?', query
				query = options.parseQuery query if options.parseQuery
				#console.log 'QUERY!', query
				return step query.error if query.error
				#
				# convert REST to RPC, to unify handling
				#
				unless data.jsonrpc and data.hasOwnProperty('method') and data.hasOwnProperty('params')
					data = convertToRPC req.method, req.location.pathname, query, data
				console.log 'CALL', data, req.context
				#return res.send data
				#
				# drill down context properties
				#
				fn = @
				if Array.isArray data.method
					fn = fn and fn[i] for i in data.method
				else
					fn = fn[data.method]
				#
				# do RPC call
				#
				if fn
					args = if Array.isArray data.params then data.params else if data.params then [data.params] else []
					args.unshift context
					args.push step
					console.log 'CALLING', args, fn.length
					# handler arguments count must coincide with args length
					return step 406 if args.length isnt fn.length
					fn.apply null, args
				else
					# no handler in context
					# check login call
					if data.method is 'login' and @verify
						@verify data.params, (err, session) -> step res.setSession err or session
					else
						# no handler here
						console.log 'NOTFOUND', data
						next()
			(err, result) ->
				#console.log 'RESULT', arguments
				#
				# compose JSON-RPC response
				#
				if data.jsonrpc
					response =
						jsonrpc: '2.0'
					#response.id = data.id if data?.id
					if err
						response.error = err.message or err
					else if result is undefined
						response.result = true
					else
						response.result = result
				#
				# compose REST response
				#
				else
					response = err or result
				# respond
				res.send response
