'use strict'

#
# improve console.log
#
#inspect = require('eyes.js').inspector stream: null
#consoleLog = console.log
#console.log = () -> consoleLog inspect arg for arg in arguments

#
# flow
#
global.Next = (context, steps...) ->
	next = (err, result) ->
		# N.B. only simple steps are supported -- no next.group() and next.parallel() as in Step
		fn = steps.shift()
		if fn
			try
				fn.call context, err, result, next
			catch err
				next err
		else
			throw err if err
		return
	next()
Object.defineProperty Next, 'nop', value: () ->

global.All = (context, steps...) ->
	next = (err, result) ->
		throw err if err
		# N.B. only simple steps are supported -- no next.group() and next.parallel() as in Step
		fn = steps.shift()
		if fn
			try
				fn.call context, err, result, next
			catch err
				console.log 'FATAL: ' + err.stack
				process.exit 1
		else
			if err
				console.log 'FATAL: ' + err.stack
				process.exit 1
		return
	next()

#
# expose Object helpers
#
global._ = require 'underscore'
require './U.obj'
require './validate'

#
# improve http.IncomingMessage
#
require './request'

#
# improve http.ServerResponse
#
require './response'

module.exports =
	Database: require './database'
	run: require './server'
	handlers: require './handlers'
