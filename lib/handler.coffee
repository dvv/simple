'use strict'

#
# nop handler
#
module.exports.nop = () -> (req, res, next) -> next()


#
# serve static content
#
module.exports.static = (options) ->

	static = new (require('static/node-static').Server)( options.dir, cache: options.ttl )

	handler = (req, res, next) ->

		# parse the request, leave body alone
		req.parse()

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

	handler = (req, res, next) ->

		if req.method is 'POST' or req.method is 'PUT'
			req.parseBody (err) ->
				return next err if err
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
module.exports.authCookie = (options) ->

	require('cookie').secret = options.secret
	cookie = options.cookie or 'uid'
	getUser = options.getUser

	if getUser
		(req, res, next) ->
			# get the user
			uid = req.getSecureCookie cookie
			#console.log "UID #{uid}"
			getUser uid, (err, user) ->
				# N.B. any error in getting user just means no user
				req.user = user or {}
				#console.log "USER", user
				#
				#
				# define session persistence method
				#
				# FIXME: efficiency?! this creates a closure for each request!
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
						req.user = {}
						#console.log 'SESSKILL'
						res.clearCookie cookie, cookieOptions
				next()
	else
		(req, res, next) ->
			# fake user
			req.user = {}
			next()

#
# jsonrpc handler
#
# given req.user.facet, try to find and execute request handler
#
# TODO: document!
#
module.exports.jsonrpc = (options) ->

	# TODO: here require RQL.parseQuery
	# TODO: require json-rpc.handle

	handler = (req, res, next) ->

		#
		# parse the query
		#
		search = req.location.search or ''
		query = parseQuery search
		#console.log 'QUERY', query
		return next URIError query.error if query.error
		#
		# find the method which will handle the request
		#
		method = req.method
		parts = req.location.pathname.substring(1).split '/'
		data = req.params
		context = req.user.context
		#
		# translate GET into fake RPC call
		#
		if method is 'GET'
			#
			# GET /Foo?query --> POST /Foo {method: 'all', params: [query]}
			# GET /Foo/ID?query --> POST /Foo {method: 'get', params: [ID]}
			#
			# FIXME: parts should be decodeURIComponent'ed
			data =
				jsonrpc: '2.0'
				id: 1
			if parts[1]
				data.method = 'get'
				data.params = [parts[1]]
			else
				data.method = 'all'
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
				args = if Array.isArray data.params then data.params else [data.params]
				# FIXME: ignore if data.id was already seen?
				# descend into context own properties
				console.log 'CALL', data
				fn = U.drill context, data.method
				if fn
					#console.log 'CALLING'
					args.push response = (err, result) ->
						#console.log 'RESULT', arguments
						#res.send err or result
						response =
							jsonrpc: data.jsonrpc
							id: data.id
						if err
							response.error = err
						else
							response.result = result
						# respond
						res.send response, 'content-type': 'application/json-rpc'
					try
						fn.apply context, args
					catch x
						response x.message
				else
					next()
			else
				next()
		else
			next()

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
