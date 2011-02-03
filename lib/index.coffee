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
global.Next = (context, steps...) ->
	next = (err, result) ->
		unless steps.length
			throw err if err
			return
		fn = steps.shift()
		try
			fn.call context, err, result, next
		catch err
			next err
		return context
	next()
Object.defineProperty Next, 'nop', value: () ->

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
