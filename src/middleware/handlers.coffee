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
# log request
#
module.exports.logRequest = (options) ->

	handler = (req, res, next) ->
		console.log "REQUEST #{req.method} #{req.url}", req.params
		next()

#
# log response
#
module.exports.logResponse = (options) ->

	handler = (req, res, next) ->
		console.log "RESPONSE", 'NYI'
		next()

#
# fetch secret cookie defining the user, lookup in db
#
module.exports.authCookie = (options = {}) ->

	Cookie = require '../helpers/cookie'
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
					#Object.freeze context
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
			[uid, pass] = new Buffer(credentials, 'base64').toString().split ':'
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
module.exports.static = (options = {}) ->

	options.root ?= 'public'
	options.default ?= 'index.html'

	require('simple-mime')
	require('./static') options.root, options

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
# REST handler
#
# given req.context, try to find there the request handler and execute it
#
module.exports.rest = (options = {}) ->

	(req, res, next) ->

		# pass thru if already JSON-RPC or parse error occured
		data = req.params
		if (typeof data is 'string') or (data.jsonrpc and data.hasOwnProperty('method') and data.hasOwnProperty('params'))
			return next()
		#
		# parse the query
		#
		query = decodeURI(req.location.search) or ''
		#
		# find the method which will handle the request
		#
		method = req.method
		parts = req.location.pathname.substring(1).split('/').map (x) -> decodeURIComponent x
		lastPart = parts.pop()
		#
		# translate REST into an RPC call
		#
		if method is 'GET'
			#
			# GET /Foo?query --> RPC {jsonrpc: '2.0', method: ['Foo', 'query'], params: [query]}
			# GET /Foo/ID?query --> RPC {jsonrpc: '2.0', method: ['Foo', 'get'], params: [ID]}
			#
			call =
				jsonrpc: '2.0'
				method: 'query'
				params: [query]
			if lastPart
				call.method = 'get'
				call.params[0] = lastPart # ??? [lastPart]
		else if method is 'PUT'
			#
			# PUT /Foo?query {changes} --> RPC {jsonrpc: '2.0', method: ['Foo', 'update'], params: [query, changes]}
			# PUT /Foo/ID?query {changes} --> RPC {jsonrpc: '2.0', method: ['Foo', 'update'], params: [[ID], changes]}
			# TODO: PUT /Foo/ID?query {ids:[], changes:changes} --> RPC {jsonrpc: '2.0', method: ['Foo', 'update'], params: [[ids], changes]}
			#
			call =
				jsonrpc: '2.0'
				method: 'update'
				params: [query, data]
			if lastPart
				call.params[0] = [lastPart]
			if data.ids and data.changes
				call.params = [data.ids, data.changes]
		else if method is 'POST'
			#
			# POST /Foo {data} --> RPC {jsonrpc: '2.0', method: ['Foo', 'add'], params: [data]}
			#
			call =
				jsonrpc: '2.0'
				method: 'add'
				params: [data]
		else if method is 'DELETE'
			#
			# DELETE /Foo?query -->RPC {jsonrpc: '2.0', method: ['Foo', 'remove'], params: [query]}
			# DELETE /Foo/ID?query --> POST /Foo {method: 'remove', params: [[ID]]}
			# DELETE /Foo/ID?query {ids:[]} --> POST /Foo {method: 'remove', params: [ids]}
			#
			call =
				jsonrpc: '2.0'
				method: 'remove'
				params: [query]
			if lastPart
				call.params[0] = [lastPart]
			if data.ids
				call.params = [data.ids]
		else
			#
			# verb not supported
			#
			return next()
		#
		# honor parts[0:-1]
		#
		if parts[0] isnt ''
			call.method = if call.method then parts.concat(call.method) else parts
		#
		# populate req.data
		#
		req.data = call
		#console.log 'DATA', req.data
		res.send req.data
		#next()
