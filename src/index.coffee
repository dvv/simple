'use strict'

###
 *
 * Simple
 * Copyright(c) 2011 Vladimir Dronnikov <dronnikov@gmail.com>
 * MIT Licensed
 *
###

### improve console.log ###
sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 10
	return

### flow control ###
require './helpers/flow'

### _ ###
global._ = require 'underscore'

module.exports =
	middleware: require './middleware'
