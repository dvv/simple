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
		node.on 'SIGQUIT', () ->
			console.error "WORKER #{node.id}: shutting down..."
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
		node.on 'exit', () ->
			console.error "WORKER #{node.id}: shutdown"
		#
		# uncaught exceptions cause worker shutdown
		#
		process.on 'uncaughtException', (err) ->
			console.error "EXCEPTION in WORKER #{node.id}: #{err.stack or err.message}"
			process.exit 1

		#
		# establish communication with master
		#
		comm = net.createConnection options.ipc

		#
		# connected to master -> ask configuration
		#
		#comm.on 'connect', () ->
		#	node.publish 'connect'

		#
		# message has arrived
		#
		comm.on 'data', (data) ->
			#console.log 'MESSAGE', data
			# TODO: robustly determine message boundaries. BTW, which ones?
			try
				data = JSON.parse data
			catch err
				# TODO: this means message boundary is not reached? Continue collecting data?
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
			comm.write JSON.stringify(msg), 'utf8'

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
			console.log 'ARGS', args
			worker = require('child_process').spawn args[0], args.slice(1),
				#cwd: undefined
				env: env
				customFds: [0, process.stdout, process.stderr]
				#setsid: false

		#
		# define broadcast message publisher
		#
		node.publish = (channel, data) ->
			msg = JSON.stringify
				from: null # master
				channel: channel
				data: data
			, 'utf8'
			_.each workers, (worker) -> worker.write msg

		#
		# create IPC server
		#
		ipc = net.createServer (stream) ->

			#
			# worker has born -> pass it configuration and the master socket to listen to
			#
			stream.write '{"foo": "bar"}', 'ascii', socket

			#
			# message from the worker
			#
			stream.on 'data', (data) ->
				# relay raw data to all known workers
				_.each workers, (worker) -> worker.write data
				# parse the message
				try
					data = data.toString 'utf8'
					data = JSON.parse data
				catch err
					# TODO: this means message boundary is not reached? Continue collecting data?
				#console.log "FROMCLIENT #{data.from}: " + JSON.stringify(data)
				# register new worker
				if data.channel is 'register'
					workers[data.from] = stream
					console.error "WORKER #{data.from} started and listening to *:#{options.port}"

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
				console.error "MASTER signalled #{signal}"
				# relay signal to all workers
				_.each workers, (worker, pid) ->
					try
						console.error "SENDING #{signal} to #{pid}"
						process.kill pid, signal
					catch err
						console.error "EMERGENCY exit to #{pid}"
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
				console.error "REPL running in the console. Use CTRL+C to stop."
			else
				net.createServer(REPL).listen options.repl
				if _.isNumber options.repl
					console.error "REPL running on 127.0.0.1:#{options.repl}. Use CTRL+C to stop."
				else
					console.error "REPL running on #{options.repl}. Use CTRL+C to stop."

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
				console.error 'watch', files
				files.forEach (file) ->
					fs.watchFile file, {interval: options.watch or 100}, (curr, prev) ->
						return if restarting
						if curr.mtime > prev.mtime
							console.error 'changed', file
							restarting = true
							process.kill process.pid, 'SIGQUIT'
							restarting = false

		#
		# uncaught exceptions cause workers respawn
		#
		process.on 'uncaughtException', (err) ->
			console.error "EXCEPTION in MASTER: #{err.stack or err.message}"
			process.kill process.pid, 'SIGHUP'

	#
	# nothing to expose
	#
	return
