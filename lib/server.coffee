'use strict'

sys = require 'util'
spawn = require('child_process').spawn
net = require 'net'
netBinding = process.binding 'net'
fs = require 'fs'
http = require 'http'
crypto = require 'crypto'

#
# FIXME: global settings
# FIXME: global facets
# FIXME: should use stack
#

#
# farm factory, takes configuration and the request handler
#
module.exports = (handler, options) ->

	# options
	options ?= {}
	options.port ?= 80

	#
	node = new process.EventEmitter()

	# setup server
	server = http.createServer()

	# SSL?
	if options.sslKey
		credentials = crypto.createCredentials
			key: fs.readFileSync options.sslKey, 'utf8'
			cert: fs.readFileSync options.sslCert, 'utf8'
			#ca: options.sslCACerts.map (fname) -> fs.readFileSync fname, 'utf8'
		server.setSecure credentials
	server.on 'request', handler

	# websocket?
	if options.websocket
		#ws = require('ws-server').createServer debug: true, server: server
		ws = require('socket.io').listen server, flashPolicyServer: false
		ws.on 'connection', (client) ->
			client.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: 'IAMIN'
			client.on 'disconnect', () ->
				ws.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: 'IAMOUT'
			client.on 'message', (message) ->
				#console.log 'MESSAGE', message
				client.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: message
		# broadcast to clients what is published to 'bcast' channel
		dbPubSub = redis.createClient()
		dbPubSub.on 'message', (channel, message) ->
			ws.broadcast JSON.stringify channel: channel, message: message.toString('utf8')
		dbPubSub.subscribe 'bcast'

	# worker branch
	if process.env._WID_

		Object.defineProperty node, 'id', value: process.env._WID_

		# obtain the master socket from the master and listen to it
		comm = new net.Stream 0, 'unix'
		data = {}
		comm.on 'data', (message) ->
			# get config from master
			data = JSON.parse message
			Object.defineProperty data, 'wid', value: node.id, enumerable: true
		comm.on 'fd', (fd) ->
			server.listenFD fd, 'tcp4'
			console.log "WORKER #{node.id} started"
		comm.resume()

	# master branch
	else

		Object.defineProperty node, 'id', value: 'master'
		Object.defineProperty node, 'isMaster', value: true

		# bind master socket
		socket = netBinding.socket 'tcp4'
		netBinding.bind socket, options.port
		netBinding.listen socket, options.connections or 128
		# attach the server if no workers needed
		server.listenFD socket, 'tcp4' unless options.workers

		# drop privileges
		try
			process.setuid options.uid if options.uid
			process.setgid options.gid if options.gid
		catch err
			console.log 'Sorry, failed to drop privileges'

		# allow to override workers arguments
		args = options.argv or process.argv
		# copy environment
		env = U.extend {}, process.env, options.env or {}

		# array of listening processes
		workers = []

		# create workers
		createWorker = (id) ->
			env._WID_ = id
			[outfd, infd] = netBinding.socketpair()
			# spawn worker process
			worker = spawn args[0], args.slice(1), env, [infd, 1, 2]
			# establish communication channel to the worker
			worker.comm = new net.Stream outfd, 'unix'
			# init respawning
			worker.on 'exit', () ->
				workers[id] = undefined
				createWorker id
			# we can pass some config to worker
			conf = {}
			# pass worker master socket
			worker.comm.write JSON.stringify(conf), 'ascii', socket
			# put worker to the slot
			workers[id] = worker

		createWorker id for id in [0...options.workers]

		# handle signals
		'SIGINT|SIGTERM|SIGKILL|SIGQUIT|SIGHUP|exit'.split('|').forEach (signal) ->
			process.on signal, () ->
				workers.forEach (worker) ->
					try
						worker.kill()
					catch e
						worker.emit 'exit'
				# we use SIGHUP to restart the workers
				process.exit() unless signal is 'exit' or signal is 'SIGHUP'

		# report usage
		unless options.quiet
			console.log "#{options.workers} worker(s) running at http" +
				(if options.sslKey then 's' else '') + "://*:#{options.port}/. Use CTRL+C to stop."

		# start REPL
		#if options.repl
		#	stdin = process.openStdin()
		#	stdin.on 'close', process.exit
		#	repl = require('repl').start 'node>', stdin

	process.errorHandler = (err) ->
		# err could be: number, string, instanceof Error, simple object
		# TODO: store exception state under filesystem and emit issue ticket
		#text = '' #err.message or err
		logText = err.stack if err.stack
		sys.debug logText
		text = err.stack if err.stack and options.stackTrace
		text or 500

	process.on 'uncaughtException', (err) ->
		# http://www.debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb
		console.log 'Caught exception: ' + err.stack
		# respawn workers
		process.kill process.pid, 'SIGHUP'

	# return
	node
