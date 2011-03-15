'use strict'

###
 *
 * Simple
 * Copyright(c) 2011 Vladimir Dronnikov <dronnikov@gmail.com>
 * MIT Licensed
 *
###

#
# simplified Step
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

#
# any exception in steps causes process.exit()
#
global.All = (context, steps...) ->
	next = (err, result) ->
		throw err if err
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
