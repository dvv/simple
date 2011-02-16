#!/usr/local/bin/coffee
'use strict'

global._ = require './node_modules/underscore'
require './src/object'
require './src/rql'
redis = require('./node_modules/redis').createClient()

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 10

redis.set "hello", "world1", (err, status) ->
	console.log arguments

redis.get "hello", (err, status) ->
	console.log arguments

#console.log _.query [{val:2000},{val:1}], '(val>1000)'
