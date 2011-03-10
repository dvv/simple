'use strict'

simple = require './lib'

#
# configuration
#
config =

	server:

		port: 3000
		workers: 1
		#uid: 65534
		#gid: 65534
		#pwd: './secured-root'
		#sslKey: '../simple-example/key.pem'
		#sslCert: '../simple-example/cert.pem'
		repl: true #30000
		pub:
			dir: 'test'
			ttl: 3600
		stackTrace: true
		watch: [__filename, 'test', 'lib']
		shutdownTimeout: 10000
		websocket: (client) ->
					process.log "WEBENTER", client.sessionId
					#client.broadcast
					#	announcement: client.sessionId + ' connected'
					client.on 'message', (message) ->
						msg =
							message: [client.sessionId, message]
						process.log "WEBMESSAGE", msg
						#client.send
						#	foo: 'bar'
						#client.broadcast msg
					client.on 'disconnect', () ->
						process.log "WEBLEAVE", client.sessionId
						#client.broadcast
						#	announcement: client.sessionId + ' disconnected'
		ipc: '.ipc'

	security:

		#bypass: true
		secret: 'change-me-on-production-server'
		root:
			id: 'root'
			email: 'place-admin@here.com'
			password: '123'
			secret: '321'
			type: 'root'

	database:

		url: '' #'mongodb://127.0.0.1/simple'
		#attrInactive: '_deleted'

#
# DB model definitions
#
schema = {}

schema.Language =
	type: 'object'
	additionalProperties: false # seal the schema -- allow only explicitly defined properties
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
			veto:
				update: true # prohibit this property in 'update' operation
		name:
			type: 'string'
		localName:
			type: 'string'

schema.Geo =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
			pattern: /^[A-Z]{2}$/
		name:
			type: 'string'
		iso3:
			type: 'string'
			pattern: /^[A-Z]{3}$/
		code:
			type: 'string'
			pattern: /^[0-9]{3}$/
		cont:
			type: 'string'
			default: 'SA'
			pattern: /^[A-Z]{2}$/
		tz:
			type: 'array'
			optional: true
			items:
				type: 'string'
				pattern: /^UTC/

schema.Course =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
		cur:
			type: 'string'
			pattern: /^[A-Z]{3}$/
		name:
			type: 'string'
		value:
			type: 'number'
		date:
			type: 'date'

#
# ...
#

s = ''
for i in [0..599]
	s += '1234567890'
TESTSTR6000 = s
TESTSTR12000 = s+s

#
# setup and run the server
#
All {},

	#
	# define DB model
	#
	(err, result, next) ->

		new simple.Database config.database.url, schema, next

	#
	# define application
	#
	(err, exposed, next) ->

		model = exposed

		facet =
			Language: simple.PermissiveFacet model.Language
			Geo: simple.RestrictiveFacet model.Geo
			Course: simple.RestrictiveFacet model.Course

		#
		# define capability object for given user uid
		#
		getContext = (uid, next) ->
			context = _.extend.apply null, [{}, facet]
			# FIXME: _.freeze is very consuming!
			next? null, _.freeze context

		#
		# define middleware stack
		#
		getHandler = (server) -> simple.stack(

			simple.handlers.jsonBody
				maxLength: 0 # set to >0 to limit the number of bytes

			simple.handlers.mount 'GET', '/foo0', (req, res, next) ->
				res.send 'GOT FROM HOME'

			#simple.handlers.getRemoteUserInfo()

			simple.handlers.mount 'GET', '/foo00', (req, res, next) ->
				res.send 'GOT FROM HOME'

			simple.handlers.authCookie
				cookie: 'uid'
				secret: config.security.secret
				getContext: getContext

			simple.handlers.mount 'GET', '/foo1', (req, res, next) ->
				res.send 'GOT FROM HOME'

			#simple.handlers.mount '/foo1',
			#	get: (req, res, next) -> res.send 'GOT FROM HOME'
			#	post: (req, res, next) -> res.send 'POSTFOO1'

			simple.handlers.dynamic
				map:
					'/': 'test/index.html'

			simple.handlers.mount 'GET', '/foo2', (req, res, next) ->
				res.send 'GOT FROM HOME'

			simple.handlers.static
				root: config.server.pub.dir
				default: 'index.html'
				#cacheMaxFileSizeToCache: 1024 # set to limit the size of cacheable file
				cacheTTL: 1000
				#process: simple.handlers.helpers.template()

			simple.handlers.mount 'GET', '/foo3', (req, res, next) ->
				res.send 'GOT FROM HOME'

			simple.handlers.mount 'GET', '/course', (req, res, next) ->
				#console.log req.location.search
				query = _.rql decodeURI(req.location.search or '')
				res.send _.query(course, query)

			simple.handlers.mount 'GET', '/geo', (req, res, next) ->
				#console.log req.location.search
				query = _.rql decodeURI(req.location.search or '')
				res.send _.query(geo, query)

			simple.handlers.mount 'GET', '/b6000', (req, res, next) ->
				res.send TESTSTR6000
			simple.handlers.mount 'GET', '/l12000', (req, res, next) ->
				res.send TESTSTR12000

			#simple.handlers.logRequest()

			simple.handlers.jsonrpc()

			simple.handlers.mount 'GET', '/a6000', (req, res, next) ->
				res.send TESTSTR6000

			simple.handlers.mount 'GET', '/foo4', (req, res, next) ->
				res.send 'GOT FROM HOME'

			simple.handlers.mount 'POST', '/foo', (req, res, next) ->
				res.send 'POSTED TO FOO'

		)

		#
		# compose application
		#
		app = Object.freeze
			#getContext: getContext
			getHandler: getHandler
			messageHandler: (broadcaster, message) -> # @ === worker
				if message.channel is 'bcast'
					console.error 'BCAST!', message
					broadcaster? message.data

		#
		# run the application
		#
		simple.run app, config.server

	#
	# define fallback
	#
	(err, result, next) ->

		console.log "OOPS, shouldn't have been here!", err
