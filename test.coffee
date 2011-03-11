'use strict'

#
# coffee quirks
#
if process.argv[1].slice(-7) is '.coffee'
	process.argv[0] = 'coffee'
	require.paths.unshift __dirname + '/node_modules'

simple = require if process.argv[0] is 'coffee' then './src' else './lib'
_ = require 'underscore'

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
		shutdownTimeout: 10000
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
getContext = (uid, next) -> next()

#
# define middleware stack
#
getHandler = (server) -> simple.stack(

	simple.handlers.jsonBody
		maxLength: 0 # set to >0 to limit the number of bytes

	simple.handlers.mount 'GET', '/foo0', (req, res, next) ->
		res.send 'GOT FROM HOME'

	simple.handlers.rest()

	simple.handlers.authCookie
		cookie: 'uid'
		secret: config.security.secret
		getContext: getContext

	simple.handlers.mount 'GET', '/foo1', (req, res, next) ->
		res.send 'GOT FROM HOME'

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

	simple.handlers.mount 'GET', '/foo3', (req, res, next) ->
		res.send 'GOT FROM HOME'

	simple.handlers.mount 'GET', '/6000', (req, res, next) ->
		res.send TESTSTR6000
	simple.handlers.mount 'GET', '/12000', (req, res, next) ->
		res.send TESTSTR12000

	#simple.handlers.authBasic
	#	getContext: getContext
	#	#realm: 'simple'

	simple.handlers.mount 'POST', '/foo', (req, res, next) ->
		res.send 'POSTED TO FOO'

)

#
# compose application
#
app =
	#getContext: getContext
	getHandler: getHandler

#
# run the application
#
simple.run app, config.server
