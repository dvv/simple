'use strict'

#
# coffee quirks
#
if process.argv[1].slice(-7) is '.coffee'
	process.argv[0] = 'coffee'
	require.paths.unshift __dirname + '/node_modules'

simple = require if process.argv[0] is 'coffee' then './src' else './lib'
require './src/database/object'

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
		watch: [__filename, 'test', 'src', 'lib']
		shutdownTimeout: 1000
		#ipc: '.ipc'

	security:

		#bypass: true
		secret: 'change-me-on-production-server'
		root:
			id: 'root'
			email: 'place-admin@here.com'
			password: '123'
			secret: '321'
			type: 'root'

#
# ...
#

s = ''
for i in [0..599]
	s += '1234567890'
TESTSTR6000 = s
TESTSTR12000 = s+s

#
# define capability object for given user uid
#
getContext = (uid, callback) ->
	context =
		user: {}
		login: (data, cb) ->
			console.log 'LOGIN'
			cb()
	callback null, context

#
# define application
#
app =
	getContext: getContext

#
# run the application
#
server = simple.run config.server

#
# subscribe to intercom messages
#
process.on 'message', () ->
	@log 'MESSAGE', arguments

#
# define middleware stack
#
if server then server.on 'request', simple.middleware(

	#simple.middleware.log()

	simple.middleware.decodeBody
		maxLength: 0 # set to >0 to limit the number of bytes
		# TODO: mime plugins

	simple.middleware.authCookie
		cookie: 'uid'
		secret: config.security.secret
		getContext: getContext

	simple.middleware.dumpParams()

	simple.middleware.mount 'POST', '/login', (req, res, next) ->
		return next 'FUCKINGSHIT!'
		session =
			uid: req.params.user
		process.log 'SESSION', session
		next res.setSession session

)

###
	simple.middleware.mount 'GET', '/foo0', (req, res, next) ->
		res.send 'GOT FROM FOO0'

	# TODO: unite
	# TODO: /login handler
	simple.middleware.authCookie
		cookie: 'uid'
		secret: config.security.secret
		getContext: getContext
	#simple.middleware.authBasic
	#	getContext: getContext
	#	#realm: 'simple'

	simple.middleware.mount 'GET', '/foo1', (req, res, next) ->
		res.send 'GOT FROM FOO1'

	#simple.middleware.rest
	#	parseQuery: _.rql

	simple.middleware.mount 'GET', '/foo2', (req, res, next) ->
		res.send 'GOT FROM FOO2'

	simple.middleware.dynamic
		map:
			'/': 'test/index.html'

	simple.middleware.mount 'GET', '/foo2', (req, res, next) ->
		res.send 'GOT FROM FOO3'

	#simple.middleware.static '/', config.server.pub.dir, 'index.html',
	#	#cacheMaxFileSizeToCache: 1024 # set to limit the size of cacheable file
	#	cacheTTL: 1000

	simple.middleware.static0
		root: config.server.pub.dir
		default: 'index.html'
		#cacheMaxFileSizeToCache: 1024 # set to limit the size of cacheable file
		cacheTTL: 1000

	simple.middleware.mount 'GET', '/foo4', (req, res, next) ->
		res.send 'GOT FROM FOO4'

	simple.middleware.mount 'GET', '/6000', (req, res, next) ->
		res.send TESTSTR6000
	simple.middleware.mount 'GET', '/12000', (req, res, next) ->
		res.send TESTSTR12000

)
###
