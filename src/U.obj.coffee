# TODO: as a separate lib

#_.mixin require '../node/underscore.string'

_.mixin

	isObject: (value) -> value and typeof value is 'object'

	# kick off properties mentioned in fields from obj
	# FIXME: should be just schema!
	veto: (obj, fields) ->
		for k in fields
			if _.isString k
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
		if _.isObject obj
			#console.log 'FREEZING', obj
			Object.freeze obj
			_.each obj, (v, k) ->
				_.freeze v
		obj

	#
	# expose enlisted object properties
	#
	proxy: (obj, exposes) ->
		facet = {}
		exposes and exposes.forEach (definition) ->
			if _.isArray definition
				name = definition[1]
				prop = definition[0]
				prop = obj[prop] if _.isString prop
			else
				name = definition
				prop = obj[name]
			#
			facet[name] = prop if prop
		Object.freeze facet

	#
	# drill down object properties specified by path
	#
	# _.get({a:{b:{c:[0,2,4]}}},['a','b','c',2]) ---> 4
	# TODO: _.get({a:{b:{get:function(attr){return{c:[0,2,4]}[attr];}}}},['a','b','c',2]) ---> 4
	#
	get: (obj, path, remove) ->
		if _.isArray path
			if remove
				[path..., name] = path
				orig = obj
				for part, index in path
					obj = obj and obj[if _.isNumber part then part else decodeURIComponent part]
				delete obj[name] if obj?[name]
				orig
			else
				for part in path
					obj = obj and obj[if _.isNumber part then part else decodeURIComponent part]
				obj
		else if path is 'undefined'
			obj
		else
			if remove
				delete obj[decodeURIComponent path]
				obj
			else
				obj[decodeURIComponent path]

	###
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
	###
