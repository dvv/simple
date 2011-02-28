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
# server farm factory, takes request handler and configuration
#
module.exports = (handler, options = {}) ->

	net = require 'net'

	# options
	options.port ?= 80
	options.ipc ?= '.ipc'

	#
	node = new process.EventEmitter()

	#
	# setup HTTP(S) server
	#
	if options.sslKey
		fs = require 'fs'
		credentials =
			key: fs.readFileSync options.sslKey, 'utf8'
			cert: fs.readFileSync options.sslCert, 'utf8'
			#ca: options.sslCACerts.map (fname) -> fs.readFileSync fname, 'utf8'
		server = require('https').createServer credentials, handler
	else
		server = require('http').createServer handler

	#
	# worker branch
	#
	if process.env._NODE_WORKER_FOR_

		#
		# establish communication with master
		#
		comm = net.createConnection options.ipc
		node.id = process.pid
		node.publish = (channel, data) ->
			msg =
				from: node.id
				channel: channel
				data: data
			comm.write JSON.stringify(msg), 'utf8'
		# connected to master -> ask configuration
		#comm.on 'connect', () ->
		#	node.publish 'connect'
		#m essage has arrived
		comm.on 'data', (data) ->
			#console.log 'MESSAGE', data
			try
				data = JSON.parse data
			catch x
			# skip self-emitted messages
			return if data.from is node.id
			console.log "MESSAGE for #{node.id}: " + JSON.stringify(data)
		# master socket has arrived
		comm.once 'fd', (fd) ->
			server.listenFD fd, 'tcp4'
			node.publish 'worker'
			console.log "WORKER started as PID #{process.pid}"
		# communication with master broken -> exit
		comm.once 'end', () ->
			process.exit 0
		#comm.on 'error', (err) ->
		#	console.log "WORKER #{node.id} faulted to communicate: #{err}"
		#	process.exit 0
		#comm.resume()
		#setInterval (() -> node.publish 'ping'), 1000

	#
	# master branch
	#
	else

		node.id = 'master'

		# bind master socket
		netBinding = process.binding 'net'
		socket = netBinding.socket 'tcp4'
		netBinding.bind socket, options.port
		netBinding.listen socket, options.connections or 1024

		# attach the server if no workers needed
		server.listenFD socket, 'tcp4' unless options.workers

		# drop privileges
		if process.getuid() is 0
			process.setuid options.uid if options.uid
			process.setgid options.gid if options.gid

		# chdir
		process.chdir options.pwd if options.pwd

		if options.workers

			#
			# utility to spawn worker process
			#
			# allow to override workers arguments
			args = options.argv or process.argv
			# copy environment
			env = _.extend {}, process.env, options.env or {}
			spawnWorker = () ->
				env._NODE_WORKER_FOR_ = process.pid
				worker = require('child_process').spawn args[0], args.slice(1),
					#cwd: undefined
					env: env
					customFds: [0, process.stdout, process.stderr]
					#setsid: false

			# array of workers
			workers = {}

			# define broadcast publisher
			node.publish = (channel, data) ->
				msg = JSON.stringify
					from: null # master
					channel: channel
					data: data
				, 'utf8'
				_.each workers, (worker) -> worker.write msg

			# create IPC socket
			#
			# TODO: what if use REPL here?!
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
					catch exc
					console.log "FROMCLIENT #{data.from}: " + JSON.stringify(data)
					# register the worker
					if data.channel is 'worker'
						workers[data.from] = stream
				#
				# worker has died
				#
				stream.on 'end', () ->
					# remove old worker
					workers = _.without workers, stream
					# start new worker
					spawnWorker()
			ipc.listen options.ipc

			# initially spawn workers
			spawnWorker() for id in [0...options.workers]

		# handle signals
		['SIGINT','SIGTERM','SIGKILL','SIGUSR2','SIGHUP','SIGQUIT','exit'].forEach (signal) ->
			process.on signal, () ->
				console.error "Master got signal #{signal}"
				_.each workers, (worker, pid) ->
					try
						process.kill pid, signal
					catch exc
						worker.emit 'exit'
				# we use SIGHUP to restart the workers
				process.exit() unless signal in ['exit', 'SIGHUP']

		#
		# REPL
		#
		# options.repl: true -- REPL on stdin
		# options.repl: <number> -- REPL on localhost:<number>
		# options.repl: <string> -- REPL on UNIX socket <string>
		if options.repl
			REPL = (stream) ->
				repl = require('repl').start 'node>', stream
				# expose master control interface
				_.extend repl.context,
					shutdown: () ->
						process.kill process.pid, 'SIGQUIT'
					restart: () ->
						process.kill process.pid, 'SIGHUP'
					stop: () ->
						process.exit 0
					spawn: (n) ->
						spawnWorker() while n-- > 0
						return
					status: () ->
						_.each workers, (worker, pid) ->
							# borrowed from 'cluster'
							try
								process.kill pid, 0
								status = 'alive'
							catch err
								if ESRCH is err.errno
									status = 'dead'
								else
									throw err
							console.log "STATUS for #{pid} is #{status}"
			# start REPL
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
	# uncaught exceptions cause workers respawn
	#
	process.on 'uncaughtException', (err) ->
		# http://www.debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb
		console.log 'Caught exception: ' + err.stack
		# respawn workers
		# TODO: what if process is worker process?
		process.kill process.pid, 'SIGHUP'

	# nothing to expose
	return
