'use strict'

#
# improve console.log
#
sys = require 'util'
inspect = require('eyes.js').inspector stream: null
consoleLog = console.log
console.log = () -> consoleLog inspect arg for arg in arguments

#
# flow
#
global.Step = require 'step'
Object.defineProperty global, 'nop', value: () ->

#
# Object helpers
#
global.Compose = require 'compose'
global._ = require 'underscore'
require './U.obj'

#
# nonce
#
crypto = require 'crypto'
rnd = () ->
	Math.random().toString().substring 2
global.nonce = () ->
	(Date.now() & 0x7fff).toString(36) + Math.floor(Math.random()*1e9).toString(36) + Math.floor(Math.random()*1e9).toString(36) + Math.floor(Math.random()*1e9).toString(36) #+ Math.floor(Math.random()*1e9).toString(36)
	#rnd() + rnd() + rnd() + rnd() + rnd() + rnd()
global.sha1 = (data, key) ->
	hmac = crypto.createHmac 'sha1', key
	hmac.update data
	hmac.digest 'hex'

#
# RQL
#
#global.parseQuery = require('rql/parser').parseGently
#global.Query = require('rql/query').Query

#global.filterArray = require('rql/js-array').executeQuery
#_.mixin
#	query: (arr, query, params) ->
#		filterArray query, params or {}, arr

#
# http.IncomingMessage
#
require './request'

#
# http.ServerResponse
#
require './response'

module.exports =
	run: require './server'
	handlers: require './handlers'
