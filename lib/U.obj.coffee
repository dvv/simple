# TODO: as a separate lib

_.mixin require 'underscore.string'

# mixin Resource Query Language
_.mixin require './rql'

# mixin json-schema validation
_validate = require './validate'
_.mixin
	validate: (instance, schema, options, next) ->
		_validate.call @, instance, schema, _.extend(options or {}, coerce: _.coerce), next

# _.drill({a:{b:{c:[0,2,4]}}},['a','b','c',2]) ---> 4
# _.drill({a:{b:{get:function(attr){return{c:[0,2,4]}[attr];}}}},['a','b','c',2]) ---> 4
_.mixin

	#
	# drill down object properties specified by path
	#
	drill: (obj, path) ->
		_drill = (obj, path) ->
			return obj unless obj and path?
			if _.isArray path
				_.each path, (part) ->
					obj = obj and _drill obj, part
				obj
			else if typeof path is 'undefined'
				obj
			else
				attr = if _.isNumber path then path else decodeURIComponent path
				# FIXME: false .get() in models, .get() requires wait()
				#obj.get and obj.get(attr) or obj[attr]
				obj[attr]
		_drill obj, path

	# kick off properties mentioned in fields from obj
	# FIXME: should be just schema!
	veto: (obj, fields) ->
		for k in fields
			if typeof k is 'string'
				delete obj[k] if obj
				#obj[k] = undefined
			else if _.isArray k
				k1 = k.shift()
				v1 = obj[k1]
				if _.isArray v1
					obj[k1] = v1.map (x) -> _.veto(x, if k.length > 1 then [k] else k)
				else if v1
					obj[k1] = _.veto(v1, if k.length > 1 then [k] else k)
		obj

	#
	# deep freeze an object
	#
	freeze: (obj) ->
		if obj and typeof obj is 'object'
			#console.log 'FREEZING', obj
			Object.freeze obj
			_.each obj, (v, k) ->
				_.freeze v
		obj

	#
	# expose enlisted object properties
	#
	proxy: (obj, expose) ->
		facet = {}
		expose and expose.forEach (definition) ->
			if _.isArray definition
				name = definition[1]
				method = definition[0]
				method = obj[method] if typeof method is 'string'
			else
				name = definition
				method = obj[name]
			#
			facet[name] = method if method
		Object.freeze facet
