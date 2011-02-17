#!/usr/local/bin/coffee
'use strict'

global._ = require './node_modules/underscore'
require './src/object'
require './src/rql'
pubsub = require('./node_modules/redis').createClient()
redis = require('./node_modules/redis').createClient()

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 10

pubsub.subscribeTo 'bcast', (channel, msg = '{}', count) ->
	console.log 'SUBSCR', channel, JSON.parse msg

pubsub.subscribeTo 'bcast1', (channel, msg = '{}', count) ->
	console.log 'SUBSCR', channel, JSON.parse msg

console.log 'SUB'

setTimeout () ->
	console.log 'PUB'
	redis.publish 'bcast', JSON.stringify {data: 'foo'}
	redis.publish 'bcast1', JSON.stringify {data: 'foo'}
, 1000
