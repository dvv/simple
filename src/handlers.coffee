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
				catch x
					req.params = x.message
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

	Cookie = require './cookie'
	cookie = options.cookie or 'uid'
	getContext = options.getContext

	if getContext

		# helper to set/clear secured cookie
		require('http').ServerResponse::setSession0000 = (session) ->
			cookieOptions = path: '/', httpOnly: true
			if _.isObject session
				# set the cookie
				cookieOptions.expires = session.expires if session.expires
				@setSecureCookie cookie, session.uid, cookieOptions
				undefined
			else
				# clear the cookie
				@clearCookie cookie, cookieOptions
				session

		# helper to set/clear secured cookie
		require('http').ServerResponse::setSession = (session) ->
			cookieOptions = path: '/', httpOnly: true
			if _.isObject session
				# set the cookie
				cookieOptions.expires = session.expires if session.expires
				@req.cookie.set cookie, session.uid, cookieOptions
				undefined
			else
				# clear the cookie
				@req.cookie.clear cookie, cookieOptions
				session

		#
		# handler
		#
		(req, res, next) ->
			req.cookie = new Cookie req, res, options.secret
			# get the user ID
			uid = req.cookie.get cookie
			#console.log "UID #{uid}"
			# attach context of that user to the request
			getContext uid, (err, context) ->
				# N.B. any error in getting user just means no user
				req.context = context or user: {}
				#console.log "USER", req.context.user
				# freeze the context
				#Object.freeze context
				#
				next()
	else
		(req, res, next) ->
			# null user
			req.context = user: {}
			next()

#
# jsonrpc handler
#
# given req.context, try to find there the request handler and execute it
#
# TODO: document!
#
module.exports.jsonrpc = (options = {}) ->

	# TODO: put here a generic json-rpc.handler

	(req, res, next) ->

		#console.log 'HEADS', req.headers
		#return next() unless req.headers.accept.split(';')[0] is 'application/json'

		Next {},
			(xxx, yyy, step) ->
				#console.log 'PARSEDBODY', req.params
				# pass errors to serializer
				return step req.params if _.isString req.params
				#
				# parse the query
				#
				search = decodeURI(req.location.search or '')
				#console.log 'QUERY?', search
				query = _.rql search
				#console.log 'QUERY!', query
				return step query.error if query.error
				#
				# find the method which will handle the request
				#
				method = req.method
				parts = _.map req.location.pathname.substring(1).split('/'), (x) -> decodeURIComponent x
				data = req.params
				context = req.context
				#
				# translate GET into fake RPC call
				#
				if method is 'GET'
					#
					# GET /Foo?query --> POST /Foo {method: 'query', params: [query]}
					# GET /Foo/ID?query --> POST /Foo {method: 'get', params: [ID]}
					#
					call =
						jsonrpc: '2.0'
						method: 'query'
						params: [query]
					if parts[1]
						call.method = 'get'
						call.params = [parts[1]]
				else if method is 'PUT'
					#
					# PUT /Foo?query {changes} --> POST /Foo {method: 'update', params: [query, changes]}
					# TODO: PUT /Foo/ID?query {changes} --> POST /Foo {method: 'update', params: [[ID], changes]}
					# TODO: PUT /Foo/ID?query {ids:[], changes:changes} --> POST /Foo {method: 'update', params: [[ids], changes]}
					#
					call =
						jsonrpc: '2.0'
						method: 'update'
						params: [query, data]
					if parts[1]
						call.params = [[parts[1]], data]
				else if method is 'POST'
					if data.jsonrpc # and data.method
						call = data
						#
						# POST / {method: M, params: P,...} --> context[M].apply context, P
						# POST /Foo {method: [M, N], params: P,...} --> context.Foo[M][N].apply context, P
						#
						# TODO:
						# update takes _array_ [query, changes]
						# FIXME: params check and recheck and triple check!!!
					else
						#
						# POST /Foo {props} --> context[Foo].add.apply context, props
						#
						call =
							jsonrpc: '2.0'
							method: 'add'
							params: [data]
				else if method is 'DELETE'
					#
					# DELETE /Foo?query --> POST /Foo {method: 'remove', params: [query]}
					# TODO: DELETE /Foo/ID?query --> POST /Foo {method: 'remove', params: [[ID]]}
					# TODO: DELETE /Foo/ID?query {ids:[]} --> POST /Foo {method: 'remove', params: [ids]}
					#
					call =
						jsonrpc: '2.0'
						method: 'remove'
						#params: if Array.isArray data?.ids then [data.ids] else [query]
						params: [query]
					if parts[1]
						call.params = [[parts[1]]]
				else
					# verb not supported
					return next()
				#
				# do RPC call
				#
				# descend into context own properties
				#
				#
				if parts[0] isnt ''
					call.method = if call.method then [parts[0], call.method] else [parts[0]]
				#console.log 'CALL', call
				fn = _.get context, call.method
				if fn
					args = if Array.isArray call.params then call.params else if call.params then [call.params] else []
					args.unshift context
					args.push step
					#console.log 'CALLING', args, fn.length
					if args.length isnt fn.length
						return step 406
					fn.apply null, args
					#return
				else
					# no handler in context
					# check login call
					if call.method is 'login' and context.verify
						context.verify call.params, (err, session) ->
							step res.setSession err or session
					else
						# no handler here
						#console.log 'NOTFOUND', call
						next()
			(err, result) ->
				#console.log 'RESULT', arguments
				#res.send err or result
				response =
					jsonrpc: '2.0'
				#response.id = data.id if data?.id
				if err
					response.error = err.message or err
				else if result is undefined
					response.result = true
				else
					response.result = result
				# respond
				#res.send response, 'content-type': 'application/json-rpc; charset=utf-8'
				res.send response

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
# serve chrome page
#
module.exports.chrome = (options = {}) ->

	handler = (req, res, next) ->

		if req.method is 'GET' and req.url is '/'
			console.log 'STATIC?', req.url
			if req.context?.user?.type
				res.send '<HTML>'+JSON.stringify(req.context.user)+'</HTML>'
			else
				res.send '<HTML1></HTML1>'
		else
			next()

#
# serve static content
#
module.exports.static_ = (options = {}) ->

	static_ = new (require('static/node-static').Server)( options.dir or 'public', cache: options.ttl or 3600 )

	handler = (req, res, next) ->

		# serve files
		# no static file? -> none of our business
		if req.method is 'GET'
			#console.log 'STATIC?', req.url
			#if options.honorType and req.context?.user?.type
			#	req.url = '/' + req.context.user.type + req.url
			#console.log 'STATIC!', req.url
			static_.serve req, res, (err, data) ->
				next() if err?.status is 404
		else
			next()
