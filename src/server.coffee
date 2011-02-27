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
	# pubsub, if any
	#
	if options.pubsub
		subscribe = require('redis').createClient()
		_.each options.pubsub, (handler, channel) -> subscribe.subscribeTo channel, handler.bind(node)

	#
	# worker branch
	#
	if process.env._WID_

		#
		# establish communication with master
		#
		comm = net.createConnection options.ipc
		node.id = +process.env._WID_
		node.publish = (channel, data) ->
			msg =
				from: node.id
				channel: channel
				data: data
			comm.write JSON.stringify(msg), 'utf8'
		# connected to master -> ask configuration
		#comm.on 'connect', () ->
		#	node.publish 'connect'
		# message has arrived
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
			#node.publish 'listen'
			console.log "WORKER #{node.id} started as PID #{process.pid}"
		# communication with master broken -> exit
		comm.once 'end', () ->
			process.exit 0
		#comm.on 'error', (err) ->
		#	console.log "WORKER #{node.id} faulted to communicate: #{err}"
		#	process.exit 0
		#comm.resume()
		#setInterval (() -> node.publish 'ping'), 1000

		#
		# add websocket handler
		#
		if options.websocket
			websocket = require('io').listen server,
				#resource: 'ws'
				flashPolicyServer: false
				transports: ['websocket', 'flashsocket', 'htmlfile', 'xhr-multipart', 'xhr-polling', 'jsonp-polling']
				#transportOptions:
				#	websocket:
				#		foo: 'bar'
			###
			websocket.clientConnect = options.websocket.onConnect
			websocket.clientDisconnect = options.websocket.onDisconnect
			websocket.clientMessage = options.websocket.onMessage
			###
			if options.pubsub
				publish = require('redis').createClient()
				###
				websocket.clientConnect = (client) ->
					publish 'client', JSON.stringify who: client, when: Date.now(), what: 'enter'
				websocket.clientDisconnect = (client) ->
					publish 'client', JSON.stringify who: client, when: Date.now(), what: 'leave'
				websocket.clientMessage = (message, client) ->
					publish 'client', JSON.stringify who: client, when: Date.now(), what: 'msg', data: message
				###
				subscribe.subscribeTo 'client', (channel, message) ->
					websocket.broadcast message

				websocket.on 'connection', (client) ->
					client.broadcast
						announcement: client.sessionId + ' connected'
					client.on 'message', (message) ->
						msg =
							message: [client.sessionId, message]
						client.broadcast msg
					client.on 'disconnect', () ->
						client.broadcast
							announcement: client.sessionId + ' disconnected'

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
			# allow to override workers arguments
			args = options.argv or process.argv
			# copy environment
			env = _.extend {}, process.env, options.env or {}

			# array of listening processes
			workers = []

			# create IPC socket
			connections = []
			# define publish
			node.publish = (channel, data) ->
				msg = JSON.stringify
					from: null # master
					channel: channel
					data: data
				, 'utf8'
				connections.forEach (c) -> c.write msg
			ipc = net.createServer (stream) ->
				# worker is created -> pass it the master socket to listen to
				#console.log 'CLIENT'
				connections.push stream
				stream.write '{"foo": "bar"}', 'ascii', socket
				# listen to messages from the worker
				stream.on 'data', (data) ->
					# relay raw data to all known connections
					connections.forEach (c) -> c.write data
					# parse the message
					try
						data = data.toString 'utf8'
						data = JSON.parse data
					catch x
					console.log "FROMCLIENT #{data.from}: " + JSON.stringify(data)
					if data.channel is 'worker'
						data.from
				# communication ended -> remove connection
				stream.on 'end', () ->
					connections = _.without connections, stream
				#stream.once 'error', (err) ->
				#	console.log "ERROR ON COMM"
			ipc.listen options.ipc

			# create workers
			spawn = require('child_process').spawn
			createWorker = (id) ->
				env._WID_ = id
				# spawn worker process
				worker = spawn args[0], args.slice(1),
					#cwd: undefined
					env: env
					customFds: [0, 1, 2]
					#setsid: false
				# init respawning
				worker.on 'exit', () ->
					worker = null
					createWorker id
				# put worker to the slot
				workers[id] = worker

			createWorker id for id in [0...options.workers]

		# handle signals
		['SIGINT','SIGTERM','SIGKILL','SIGHUP','exit'].forEach (signal) ->
			process.on signal, ->
				workers.forEach (worker) ->
					try
						worker.kill()
					catch e
						worker.emit 'exit'
				# we use SIGHUP to restart the workers
				process.exit() unless signal in ['exit', 'SIGHUP']

		# report usage
		console.log "#{options.workers} worker(s) running at http" +
			(if options.sslKey then 's' else '') + "://*:#{options.port}. Use CTRL+C to stop."

		# start REPL
		if options.repl
			process.stdin.on 'close', process.exit
			global.node = node
			repl = require('repl').start 'node>'

	#
	# uncaught exceptions cause workers respawn
	#
	process.on 'uncaughtException', (err) ->
		# http://www.debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb
		console.log 'Caught exception: ' + err.stack
		# respawn workers
		process.kill process.pid, 'SIGHUP'

	# nothing to expose
	return
