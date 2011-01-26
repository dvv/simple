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
				cb = @
				if req.method is 'POST' and req.headers['content-type'].split(';')[0] is 'application/json'
					req.params = {}
					body = ''
					req.on 'data', (chunk) ->
						body += chunk.toString 'utf8'
						# fuser not to exhaust memory
						if body.length > options.maxBodyLength > 0
							cb 'Length exceeded'
					req.on 'end', () ->
						try
							# TODO: use kriszyp's one to relax accepted formatting?
							req.params = JSON.parse body
							cb()
						catch x
							cb x.message
					undefined
				else
					null
			(err) ->
				#console.log 'PARSEDBODY', err, req.params
				cb = @
				# pass errors to serializer
				if err
					cb err
					return  
				#
				# parse the query
				#
				search = req.location.search or ''
				query = parseQuery search
				#console.log 'QUERY', query
				if query.error
					cb query.error
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
					# GET /Foo?query --> POST /Foo {method: 'all', params: [query]}
					# GET /Foo/ID?query --> POST /Foo {method: 'get', params: [ID]}
					#
					# N.B. parts are decodeURIComponent'ed in U.drill
					data =
						jsonrpc: '2.0'
						id: 1
					if parts[1]
						data.method = 'get'
						data.params = [parts[1]]
					else
						data.method = 'query'
						data.params = [query]
					method = 'POST'
				if method is 'POST'
					#
					# POST / {method: M, params: P,...} --> context[M].apply context, P
					# POST /Foo {method: [M, N], params: P,...} --> context.Foo[M][N].apply context, P
					#
					data.method = [parts[0], data.method] unless parts[0] is ''
					#r = jsonrpc.handle context, data
					# TODO: multiple chunks
					if data.jsonrpc and data.id and data.method
						# FIXME: ignore if data.id was already seen?
						# descend into context own properties
						#
						# TODO:
						# update takes _array_ [query, changes]
						#
						#
						#console.log 'CALL', data
						fn = U.drill context, data.method
						if fn
							args = if Array.isArray data.params then data.params else [data.params]
							args.push cb
							console.log 'CALLING', args
							fn.apply context, args
						else
							cb 'Forbidden'
							return
					else
						cb 'Invalid format'
						return
				else
					next()
					return
			(err, result) ->
				console.log 'RESULT', arguments
				#res.send err or result
				response =
					jsonrpc: data?.jsonrpc or '2.0'
				response.id = data.id if data?.id
				if err
					response.error = err.message or err
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
