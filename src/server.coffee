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
# thanks 'LearnBoost/cluster'
# takes chunks in buffer. when the buffer contains valid JSON literal
# reset the buffer and emit 'message' event passing parsed JSON as parameter
#
# usage: stream.on('data', framing.bind(stream))
#
framing = (chunk) ->
	buf = buf or ''
	braces = braces or 0
	for c, i in chunk
		++braces if '{' is c
		--braces if '}' is c
		buf += c
		if 0 is braces
			obj = JSON.parse buf
			buf = ''
			@emit 'message', obj

#
# node cluster factory, takes request handler and configuration
#
module.exports = (app, options = {}) ->

	net = require 'net'
	fs = require 'fs'

	# options
	options.port ?= 80
	nworkers = options.workers or require('os').cpus().length
	options.ipc ?= '.ipc'

	####################################################################
	#
	# worker branch
	#
	####################################################################

	if process.env._NODE_WORKER_FOR_

		#
		# define logger
		#
		process.log = (args...) ->
			args[0] = "#{Date.now()} WORKER #{process.pid}: " + args[0]
			console.error.apply console, args

		#
		# setup HTTP(S) server
		#
		if options.sslKey
			credentials =
				key: fs.readFileSync options.sslKey, 'utf8'
				cert: fs.readFileSync options.sslCert, 'utf8'
				#ca: options.sslCACerts.map (fname) -> fs.readFileSync fname, 'utf8'
			server = require('https').createServer credentials
		else
			server = require('http').createServer()

		# attach request handler
		# N.B. such pervert way of defining handler is for handler factory to have reference to the server!
		server.on 'request', app.getHandler server

		if options.websocket
			websocket = require('io').listen server,
				#resource: 'ws'
				flashPolicyServer: false
				#transports: ['websocket', 'flashsocket', 'htmlfile', 'xhr-multipart', 'xhr-polling', 'jsonp-polling']
				transports: ['websocket', 'xhr-polling'] #, 'htmlfile']
				#transportOptions:
				#	websocket:
				#		foo: 'bar'
			websocket.on 'connection', options.websocket

		#
		# setup signals
		#
		#
		# graceful shutdown, if timeout specified
		#
		if options.shutdownTimeout
			process.on 'SIGQUIT', () ->
				@log 'shutting down...'
				if server.connections
					# stop accepting
					server.watcher.stop()
					# check pending connections
					setInterval (-> server.connections or process.exit 0), 2000
					# timeout
					setTimeout (-> process.exit 0), options.shutdownTimeout
				else
					@exit 0
		#
		# exit
		#
		process.on 'exit', () ->
			@log 'shutdown'
		#
		# uncaught exceptions cause worker shutdown
		#
		process.on 'uncaughtException', (err) ->
			@log "EXCEPTION: #{err.stack or err.message}"
			@exit 1

		#
		# establish communication with master
		#
		comm = net.createConnection options.ipc

		#
		# connected to master -> setup the stream
		#
		comm.on 'connect', () ->
			comm.setEncoding 'utf8'
			#process.publish 'connect'

		#
		# wait for complete JSON message to come, parse it and emit 'message' event
		#
		comm.on 'data', framing.bind comm

		#
		# message has arrived
		#
		if app.messageHandler
			comm.on 'message', app.messageHandler.bind process, (websocket?.broadcast?.bind websocket)

		#
		# master socket descriptor has arrived
		#
		comm.once 'fd', (fd) ->
			# listen to the master socket
			server.listenFD fd
			# register the worker
			process.publish 'register'

		#
		# master has gone -> exit
		#
		comm.once 'end', () ->
			process.exit()

		#
		# define message publisher
		#
		process.publish = (channel, message) ->
			data =
				from: @pid
				channel: channel
				data: message
			comm.write JSON.stringify data

		#
		# keep-alive?
		#
		#setInterval (() -> process.publish 'bcast', foo: 'bar'), 10000

	####################################################################
	#
	# master branch
	#
	####################################################################

	else

		#
		# define logger
		#
		process.log = (args...) ->
			args[0] = "MASTER: " + args[0]
			console.error.apply console, args

		#
		# bind master socket
		#
		netBinding = process.binding 'net'
		socket = netBinding.socket 'tcp' + (if netBinding.isIP(options.host) is 6 then 6 else 4)
		netBinding.bind socket, options.port
		netBinding.listen socket, options.connections or 1024

		#
		# drop privileges
		#
		if process.getuid() is 0
			process.setuid options.uid if options.uid
			process.setgid options.gid if options.gid

		#
		# chdir
		#
		process.chdir options.pwd if options.pwd

		#
		# setup IPC
		#
		workers = {} # array of workers
		args = options.argv or process.argv # allow to override workers arguments
		# copy environment
		env = {}
		env[k] = v for own k, v of process.env
		env[k] = v for own k, v of options.env or {}
		spawnWorker = () ->
			env._NODE_WORKER_FOR_ = process.pid
			worker = require('child_process').spawn args[0], args.slice(1),
				#cwd: undefined
				env: env
				customFds: [0, process.stdout, process.stderr]
				#setsid: false

		#
		# define broadcast message publisher
		#
		process.publish = (channel, message) ->
			data = JSON.stringify
				from: null # master
				channel: channel
				data: message
			worker.write data for pid, worker of workers
			return

		#
		# create IPC server
		#
		ipc = net.createServer (stream) ->

			#
			# setup the stream
			#
			stream.setEncoding 'utf8'

			#
			# worker has born -> pass it configuration and the master socket to listen to
			#
			stream.write '{"foo": "bar"}', 'ascii', socket

			#
			# relay raw data to all known workers
			#
			#stream.on 'data', (data) -> worker.write data for pid, worker of workers

			#
			# wait for complete JSON object to come, parse it and emit 'message' event
			#
			stream.on 'data', framing.bind stream

			#
			# message from a worker
			#
			stream.on 'message', (data) ->
				# register new worker
				if data.channel is 'bcast'
					data = JSON.stringify data
					worker.write data for pid, worker of workers
				else if data.channel is 'register'
					workers[data.from] = stream
					process.log "WORKER #{data.from} started and listening to *:#{options.port}"
				return

			#
			# worker has gone
			#
			stream.on 'end', () ->
				# unregister gone worker
				for pid, worker of workers
					if worker is stream
						delete workers[pid]
				# start new worker
				spawnWorker() if nworkers > Object.keys(workers).length
				return

		#
		# start IPC server
		#
		ipc.listen options.ipc, () ->
			# spawn initial workers
			spawnWorker() for id in [0...nworkers]
			return

		#
		# handle signals
		#
		['SIGINT','SIGTERM','SIGKILL','SIGUSR2','SIGHUP','SIGQUIT','exit'].forEach (signal) ->
			process.on signal, () ->
				@log "signalled #{signal}"
				# relay signal to all workers
				for pid, worker of workers
					try
						process.log "sending #{signal} to WORKER #{pid}"
						process.kill pid, signal
					catch err
						process.log "sending EMERGENCY exit to WORKER #{pid}"
						worker.emit 'exit'
				# SIGHUP just restarts workers, SIGQUIT gracefully restarts workers
				process.exit() unless signal in ['exit', 'SIGHUP', 'SIGQUIT']

		#
		# REPL
		#
		# options.repl: true -- REPL on stdin
		# options.repl: <number> -- REPL on localhost:<number>
		# options.repl: <string> -- REPL on UNIX socket <string>
		#
		if options.repl

			#
			# define REPL handler and context
			#
			REPL = (stream) ->
				repl = require('repl').start 'node>', stream
				# expose master control interface
				repl.context[k] = v for k, v of {
					app: app
					shutdown: () ->
						nworkers = 0
						process.kill process.pid, 'SIGQUIT'
						process.exit 0
					stop: () ->
						process.exit 0
					respawn: () ->
						process.kill process.pid, 'SIGQUIT'
					restart: () ->
						process.kill process.pid, 'SIGHUP'
					spawn: (n) ->
						# add workers
						if n > 0
							while n-- > 0
								setTimeout () ->
									spawnWorker()
									# adjust max workers count
									++nworkers
								, n * 1000
						# remove workers
						else if n < 0
							# adjust max workers count
							nworkers = Math.max(0, nworkers + n)
							# shutdown all workers, spawn at most nworkers
							process.kill process.pid, 'SIGQUIT'
						return
					mem: () ->
						console.log process.memoryUsage()
					status: () ->
						console.log "TOTAL #{Object.keys(workers).length} worker(s)\n"
						for pid, worker of workers
							# thanks 'LearnBoost/cluster'
							try
								process.kill pid, 0
								status = 'alive'
							catch err
								if ESRCH is err.errno
									status = 'dead'
								else
									throw err
							console.log "STATUS for #{pid} is #{status}"
						return
				}
				return

			#
			# start REPL
			#
			if options.repl is true
				process.stdin.on 'close', process.exit
				REPL()
				process.log "REPL running in the console. Use CTRL+C to stop."
			else
				net.createServer(REPL).listen options.repl
				if typeof options.repl is 'number'
					process.log "REPL running on 127.0.0.1:#{options.repl}. Use CTRL+C to stop."
				else
					process.log "REPL running on #{options.repl}. Use CTRL+C to stop."

		#
		# setup watchdog, to reload modified source files
		# taken from spark2
		#
		#
		# TODO: elaborate on inhibit restarting if restarting in progress
		#
		if options.watch
			watch = options.watch.join(' ')
			#cmd = "find #{watch} -name '*.js' -o -name '*.coffee'"
			cmd = "find #{watch}"
			require('child_process').exec cmd, (err, out) ->
				restarting = false
				files = out.trim().split '\n'
				#process.log err, "WATCH?: #{files}"
				files.forEach (file) ->
					process.log "WATCH: #{file}"
					fs.watchFile file, {interval: options.watch or 100}, (curr, prev) ->
						return if restarting
						if curr.mtime > prev.mtime
							process.log "#{file} has changed, respawning"
							restarting = true
							process.kill process.pid, 'SIGQUIT'
							restarting = false

		#
		# uncaught exceptions cause workers respawn
		#
		process.on 'uncaughtException', (err) ->
			process.log "EXCEPTION: #{err.stack or err.message}"
			process.kill process.pid, 'SIGHUP'

	#
	# nothing to expose
	#
	return
