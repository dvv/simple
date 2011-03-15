'use strict'

###
 *
 * Simple
 * Copyright(c) 2011 Vladimir Dronnikov <dronnikov@gmail.com>
 * MIT Licensed
 *
###

###
various helpers
###

template = (options = {}) ->
	tmplSyntax = options.syntax or {
		evaluate    : /\{\{([\s\S]+?)\}\}/g
		interpolate : /\$\{([\s\S]+?)\}/g
	}
	types = options.extensions or {
		'.html': (data) -> _.template data.toString('utf8'), null, tmplSyntax
	}
	(data, name) ->
		for ext, fn of types
			if name.slice(-ext.length) is ext
				return fn data
		data

module.exports =
	template: template
