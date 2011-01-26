'use strict'

#
# nop handler
#
module.exports.nop = () -> (req, res, next) -> next()


#
# serve static content
#
module.exports.static = (options) ->

	options ?= {}

	static = new (require('static/node-static').Server)( options.dir or 'public', cache: options.ttl or 3600 )

	handler = (req, res, next) ->

		# parse the request, leave body alone
		req.parse()

		# attach request to response
		res.req = req
		res.headers ?= {}

		# serve files
		# no static file? -> none of our business
		if req.method is 'GET'
			static.serve req, res, (err, data) ->
				next() if err?.status is 404
		else
			next()

#
# decode request body
#
module.exports.body = (options) ->

	options ?= {}

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
module.exports.jsonBody123123123 = (options) ->

	options ?= {}

	(req, res, next) ->

		if (req.method is 'POST' or req.method is 'PUT') and req.headers['content-type'].split(';')[0] is 'application/json'
			req.params = {}
			body = ''
			req.on 'data', (chunk) ->
				body += chunk.toString 'utf8'
				# fuser not to exhaust memory
				if body.length > options.maxLength > 0
					next TypeError 'Max length exceeded'
			req.on 'end', () ->
				try
					# TODO: use kriszyp's one?
					req.params = JSON.parse body
					next()
				catch x
					next SyntaxError x.message
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
module.exports.authCookie = (options) ->

	options ?= {}

	require('cookie').secret = options.secret
	cookie = options.cookie or 'uid'
	getContext = options.getContext

	if getContext
		(req, res, next) ->
			# get the user
			uid = req.getSecureCookie cookie
			#console.log "UID #{uid}"
			getContext uid, (err, context) ->
				# N.B. any error in getting user just means no user
				req.context = context or user: {}
				#console.log "USER", req.context.user
				#
				#
				# define session persistence method
				#
				# FIXME: efficiency?! this creates a closure for each request!
				# TODO: use res.req in res.send!
				#
				#
				req.remember = (session) ->
					cookieOptions = path: '/', httpOnly: true
					if session
						#console.log 'SESSSET', session
						# set the cookie
						cookieOptions.expires = session.expires if session.expires
						res.setSecureCookie cookie, session.uid, cookieOptions
					else
						req.context = user: {}
						#console.log 'SESSKILL'
						res.clearCookie cookie, cookieOptions
				next()
	else
		(req, res, next) ->
			# fake user
			req.context = user: {}
			next()

#
# jsonrpc handler
#
# given req.user.facet, try to find and execute request handler
#
# TODO: document!
#
module.exports.jsonrpc = (options) ->

	options ?= {}

	# TODO: here require RQL.parseQuery
	# TODO: require json-rpc.handle

	(req, res, next) ->

		Step(
			() ->
				nextStep = @
				if (req.method is 'POST' or req.method is 'PUT')  and req.headers['content-type'].split(';')[0] is 'application/json'
					req.params = {}
					body = ''
					req.on 'data', (chunk) ->
						body += chunk.toString 'utf8'
						# fuser not to exhaust memory
						if body.length > options.maxBodyLength > 0
							nextStep 'Length exceeded'
					req.on 'end', () ->
						try
							# TODO: use kriszyp's one to relax accepted formatting?
							req.params = JSON.parse body
							nextStep()
						catch x
							nextStep x.message
					return
				else
					null
			(err) ->
				#console.log 'PARSEDBODY', err, req.params
				nextStep = @
				# pass errors to serializer
				if err
					nextStep err
					return
				#
				# parse the query
				#
				search = req.location.search or ''
				query = parseQuery search
				#console.log 'QUERY', query
				if query.error
					nextStep query.error
					return
				#
				# find the method which will handle the request
				#
				method = req.method
				parts = req.location.pathname.substring(1).split '/'
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
					# N.B. parts are decodeURIComponent'ed in U.drill
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
					# PUT /Foo/ID?query {changes} --> POST /Foo {method: 'update', params: [[ID], changes]}
					#
					call =
						jsonrpc: '2.0'
						method: 'update'
						params: [query, data]
					if parts[1]
						call.params = [[parts[1]], data]
				else if method is 'POST'
					if data.jsonrpc and data.method
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
					# DELETE /Foo/ID?query --> POST /Foo {method: 'remove', params: [[ID]]}
					# DELETE /Foo/ID?query {ids:[]} --> POST /Foo {method: 'remove', params: [ids]}
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
				call.method = [parts[0], call.method] unless parts[0] is ''
				console.log 'CALL', call
				fn = U.drill context, call.method
				if fn
					args = if Array.isArray call.params then call.params else [call.params]
					args.push nextStep
					if args.length isnt fn.length
						return nextStep 406
					console.log 'CALLING', args, fn.length
					fn.apply context, args
					return
				else
					nextStep 403
					#return
			(err, result) ->
				console.log 'RESULT', arguments
				#res.send err or result
				response =
					jsonrpc: '2.0'
				#response.id = data.id if data?.id
				if err
					response.error = err.message or err
				else if result is null
					response.error = 404
				else
					response.result = result or true
				# respond
				#res.headers['content-type'] = 'application/json-rpc; charset=utf-8'
				#next null, response
				res.send response, 'content-type': 'application/json-rpc; charset=utf-8'
		)

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
