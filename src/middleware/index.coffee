'use strict'

###
 *
 * Simple middleware
 * Copyright(c) 2011 Vladimir Dronnikov <dronnikov@gmail.com>
 * MIT Licensed
 *
###

#
# improve http.IncomingMessage
#
require './request'

#
# improve http.ServerResponse
#
require './response'

#
# thanks creationix/Stack
#
Stack = (layers...) ->
	handle = errorHandler
	layers.reverse().forEach (layer) ->
		child = handle
		handle = (req, res) ->
			try
				layer req, res, (err) ->
					return errorHandler req, res, err if err
					child req, res
			catch err
				errorHandler req, res, err
	handle

#
# mixin handlers
#
Stack[name] = fn for own name, fn of require('./handlers')

#
# fallback and error handler
#
errorHandler = (req, res, err) ->
	if err
		# TODO: configurable
		console.error err.stack or err.message
		res.send err
		return
	res.send 404

module.exports = Stack
