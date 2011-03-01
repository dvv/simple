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
# borrowed from 'cluster'.
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
module.exports = (handler, options = {}) ->

	net = require 'net'
	fs = require 'fs'

	# options
	options.port ?= 80
	nworkers = options.workers or require('os').cpus().length
	options.ipc ?= '.ipc'

	#
	node = new process.EventEmitter()

	####################################################################
	#
	# worker branch
	#
	####################################################################

	if process.env._NODE_WORKER_FOR_

		#
		# define logger
		#
		node.log = (args...) ->
			args[0] = "WORKER #{node.id}: " + args[0]
			console.error.apply console, args

		#
		# setup HTTP(S) server
		#
		if options.sslKey
			credentials =
				key: fs.readFileSync options.sslKey, 'utf8'
				cert: fs.readFileSync options.sslCert, 'utf8'
				#ca: options.sslCACerts.map (fname) -> fs.readFileSync fname, 'utf8'
			server = require('https').createServer credentials, handler
		else
			server = require('http').createServer handler

		#
		# setup signals
		#
		process.on 'SIGQUIT', () ->
			node.log 'shutting down...'
			if server.connections
				# stop accepting
				server.watcher.stop()
				# check pending connections
				setInterval (-> server.connections or process.exit 0), 2000
				# timeout
				if options.timeout
					setTimeout (-> process.exit 0), options.timeout
			else
				process.exit 0
		#
		# exit
		#
		process.on 'exit', () ->
			node.log 'shutdown'
		#
		# uncaught exceptions cause worker shutdown
		#
		process.on 'uncaughtException', (err) ->
			node.log "EXCEPTION: #{err.stack or err.message}"
			process.exit 1

		#
		# establish communication with master
		#
		comm = net.createConnection options.ipc

		#
		# connected to master -> setup the stream
		#
		comm.on 'connect', () ->
			comm.setEncoding 'utf8'
			#node.publish 'connect'

		#
		# wait for complete JSON object to come, parse it and emit 'message' event
		#
		comm.on 'data', framing.bind comm

		#
		# message has arrived
		#
		comm.on 'message', (data) ->
			# skip self-emitted messages
			return if data.from is node.id
			# pubsub
			# TODO: channel pattern match?
			if options.pubsub
				options.pubsub[data.channel]?.call node, data.channel, data.data
				options.pubsub.all?.call node, data.channel, data.data

		#
		# master socket has arrived
		#
		comm.once 'fd', (fd) ->
			# listen to the master socket
			server.listenFD fd
			# register the worker
			node.id = process.pid # id is simply PID
			node.publish 'register'

		#
		# master has gone -> exit
		#
		comm.once 'end', () ->
			process.exit 0

		#
		# define message publisher
		#
		node.publish = (channel, data) ->
			msg =
				from: node.id
				channel: channel
				data: data
			comm.write JSON.stringify msg

		#
		# keep-alive?
		#
		#setInterval (() -> node.publish 'ping'), 2000

	####################################################################
	#
	# master branch
	#
	####################################################################

	else

		node.id = 'master'

		#
		# define logger
		#
		node.log = (args...) ->
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
		env = _.extend {}, process.env, options.env or {} # copy environment
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
		node.publish = (channel, message) ->
			data = JSON.stringify
				from: null # master
				channel: channel
				data: message
			_.each workers, (worker) -> worker.write data

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
			stream.on 'data', (data) -> _.each workers, (worker) -> worker.write data

			#
			# wait for complete JSON object to come, parse it and emit 'message' event
			#
			stream.on 'data', framing.bind stream

			#
			# message from the worker
			#
			stream.on 'message', (data) ->
				#node.log "FROMCLIENT #{data.from}: " + JSON.stringify(data)
				# register new worker
				if data.channel is 'register'
					workers[data.from] = stream
					node.log "WORKER #{data.from} started and listening to *:#{options.port}"

			#
			# worker has gone
			#
			stream.on 'end', () ->
				# unregister gone worker
				workers = _.without workers, stream
				# start new worker
				spawnWorker() if nworkers > _.size workers

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
				node.log "signalled #{signal}"
				# relay signal to all workers
				_.each workers, (worker, pid) ->
					try
						node.log "sending #{signal} to WORKER #{pid}"
						process.kill pid, signal
					catch err
						node.log "sending EMERGENCY exit to WORKER #{pid}"
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
				_.extend repl.context,
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
								spawnWorker()
								# adjust max workers count
								++nworkers
						# remove workers
						else if n < 0
							# adjust max workers count
							nworkers += n
							nworkers = 0 if nworkers < 0
							# shutdown all workers, spawn at most nworkers
							process.kill process.pid, 'SIGQUIT'
						return
					status: () ->
						_.each workers, (worker, pid) ->
							# taken from 'cluster'
							try
								process.kill pid, 0
								status = 'alive'
							catch err
								if ESRCH is err.errno
									status = 'dead'
								else
									throw err
							console.log "STATUS for #{pid} is #{status}"

			#
			# start REPL
			#
			if options.repl is true
				process.stdin.on 'close', process.exit
				REPL()
				node.log "REPL running in the console. Use CTRL+C to stop."
			else
				net.createServer(REPL).listen options.repl
				if _.isNumber options.repl
					node.log "REPL running on 127.0.0.1:#{options.repl}. Use CTRL+C to stop."
				else
					node.log "REPL running on #{options.repl}. Use CTRL+C to stop."

		#
		# setup watchdog, to reload modified source files
		# taken from spark2
		#
		#
		# TODO: elaborate on inhibit restarting if restarting in progress
		#
		if options.watch
			watch = options.watch.join(' ')
			cmd = "find #{watch} -name '*.js' -o -name '*.coffee'"
			require('child_process').exec cmd, (error, out) ->
				restarting = false
				files = out.trim().split '\n'
				files.forEach (file) ->
					fs.watchFile file, {interval: options.watch or 100}, (curr, prev) ->
						return if restarting
						if curr.mtime > prev.mtime
							node.log "#{file} has changed, respawning"
							restarting = true
							process.kill process.pid, 'SIGQUIT'
							restarting = false

		#
		# uncaught exceptions cause workers respawn
		#
		process.on 'uncaughtException', (err) ->
			node.log "EXCEPTION: #{err.stack or err.message}"
			process.kill process.pid, 'SIGHUP'

	#
	# nothing to expose
	#
	return
