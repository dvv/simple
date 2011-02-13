#!/usr/local/bin/coffee
'use strict'

process.argv.shift() # still report 'node' as argv[0]

simple = require './src'

#
# configuration
#
config =

	server:

		port: 3000
		workers: require('os').cpus().length
		#uid: 65534
		#gid: 65534
		#pwd: './secured-root'
		#sslKey: 'key.pem'
		#sslCert: 'cert.pem'
		repl: true
		pub:
			dir: 'test'
			ttl: 3600
		stackTrace: true

	security:

		#bypass: true
		secret: 'change-me-on-production-server'
		roots:
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
#
# ...
#

PermissiveFacet = (obj, plus...) ->
	# register permissive facet -- set of entity accessors
	expose = ['schema', 'id', 'query', 'get', 'add', 'update', 'remove', 'delete', 'undelete', 'purge']
	expose = expose.concat plus if plus.length
	_.proxy obj, expose


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
			Language: PermissiveFacet model.Language

		#
		# app should provide for .getContext(uid, next) -- the method to retrieve
		#   capability object for given user uid
		#
		app = Object.freeze
			getContext: (uid, next) ->
				context = _.extend.apply null, [{}, facet]
				next? null, _.freeze context
		next null, app

	#
	# define server
	#
	(err, app, next) ->

		#
		# define middleware stack
		#
		handler = simple.stack(

			simple.handlers.jsonBody
				maxLength: 0 # set to >0 to limit the number of bytes

			#simple.handlers.mount '/foo1',
			#	get: (req, res, next) -> res.send 'GETFOO1'
			#	post: (req, res, next) -> res.send 'POSTFOO1'

			simple.handlers.authCookie
				cookie: 'uid'
				secret: config.security.secret
				getContext: app.getContext

			simple.handlers.mount 'GET', '/home', (req, res, next) ->
				res.send 'GOT FROM HOME'

			#simple.handlers.logRequest()

			simple.handlers.jsonrpc()

			simple.handlers.mount 'POST', '/foo', (req, res, next) ->
				res.send 'POSTED TO FOO'

			simple.handlers.static_
				dir: config.server.pub.dir
				ttl: config.server.pub.ttl

		)

		#
		# run the application
		#
		#
		simple.run handler, config.server

	#
	# define fallback
	#
	(err, result, next) ->

		console.log "OOPS, shouldn't have been here!", err
