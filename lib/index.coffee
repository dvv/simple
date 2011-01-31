'use strict'

#
# improve console.log
#
inspect = require('eyes.js').inspector stream: null
consoleLog = console.log
console.log = () -> consoleLog inspect arg for arg in arguments

#
# flow
#
global.Step = require 'step'
Object.defineProperty Step, 'nop', value: () ->

#
# expose Object helpers
#
global._ = require 'underscore'
require './U.obj'

#
# improve http.IncomingMessage
#
require './request'

#
# improve http.ServerResponse
#
require './response'

module.exports =
	run: require './server'
	handlers: require './handlers'
