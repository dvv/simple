'use strict'

#
# farm factory, takes request handler and configuration
#
module.exports = (handler, options = {}) ->

	net = require 'net'

	# options
	options.port ?= 80

	#
	node = new process.EventEmitter()

	# setup server
	# SSL?
	if options.sslKey
		fs = require 'fs'
		credentials =
			key: fs.readFileSync options.sslKey, 'utf8'
			cert: fs.readFileSync options.sslCert, 'utf8'
			#ca: options.sslCACerts.map (fname) -> fs.readFileSync fname, 'utf8'
		server = require('https').createServer credentials, handler
	else
		server = require('http').createServer handler

	# worker branch
	if process.env._WID_

		Object.defineProperty node, 'id', value: process.env._WID_

		conf = {}
		# obtain the master socket from the master and listen to it
		comm = new net.Stream 0, 'unix'
		comm.on 'data', (message) ->
			# get config from master
			conf = JSON.parse message
			Object.defineProperty conf, 'wid', value: node.id
		comm.on 'fd', (fd) ->
			# TODO: could use conf passed from master
			server.listenFD fd, 'tcp4'
			console.log "WORKER #{node.id} started as PID #{process.pid}"
		comm.resume()

	# master branch
	else

		Object.defineProperty node, 'id', value: 'master'
		Object.defineProperty node, 'isMaster', value: true

		# bind master socket
		netBinding = process.binding 'net'
		socket = netBinding.socket 'tcp4'
		netBinding.bind socket, options.port
		netBinding.listen socket, options.connections or 128

		# attach the server if no workers needed
		server.listenFD socket, 'tcp4' unless options.workers

		# drop privileges
		if process.getuid() is 0
			process.setuid options.uid if options.uid
			process.setgid options.gid if options.gid

		# chdir
		process.chdir options.pwd if options.pwd

		# allow to override workers arguments
		args = options.argv or process.argv
		# copy environment
		env = _.extend {}, process.env, options.env or {}

		# array of listening processes
		workers = []

		# create workers
		spawn = require('child_process').spawn
		createWorker = (id) ->
			env._WID_ = id
			[outfd, infd] = netBinding.socketpair()
			# spawn worker process
			console.error args
			worker = spawn args[0], args.slice(1),
				#cwd: undefined
				env: env
				customFds: [infd, 1, 2]
				#setsid: false
			# establish communication channel to the worker
			worker.comm = new net.Stream outfd, 'unix'
			# init respawning
			worker.on 'exit', () ->
				workers[id] = undefined
				createWorker id
			# we can pass some config to worker
			conf = {}
			# pass worker master socket
			worker.comm.write JSON.stringify(conf), 'utf8', socket
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
				(if options.sslKey then 's' else '') + "://*:#{options.port}. Use CTRL+C to stop."

		# start REPL
		if options.repl
			process.stdin.on 'close', process.exit
			repl = require('repl').start 'node>'

	process.on 'uncaughtException', (err) ->
		# http://www.debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb
		console.log 'Caught exception: ' + err.stack
		# respawn workers
		process.kill process.pid, 'SIGHUP'

	# return
	node
