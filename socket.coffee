#!/usr/local/bin/coffee
'use strict'

net = require 'net'

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 10

#conn = net.createConnection('ipc')
s = new net.Stream()
s.connect '/tmp/ipc'
