# TODO: as a separate lib

_.mixin

	#
	# naive check if `value` is an object
	#
	isObject: (value) ->
		value and typeof value is 'object'

	#
	# ensure passed `value` is an array; make the array of the single
	# item `value` otherwise
	#
	ensureArray: (value) ->
		return (if value is undefined then [] else [value]) unless value
		return [value] if _.isString value
		_.toArray value

	#
	# deep freeze an object
	#
	freeze: (obj) ->
		if _.isObject obj
			Object.freeze obj
			_.each obj, (v, k) -> _.freeze v
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
	# drill down along object properties specified by path
	# removes the said property and return mangled object if `remove` is truthy
	#
	# _.get({a:{b:{c:[0,2,4]}}},['a','b','c',2]) ---> 4
	# TODO: _.get({a:{b:{$ref:function(attr){return{c:[0,2,4]}[attr];}}}},['a','b','c',2]) ---> 4
	# TODO: _.get({a:{b:{$ref:function(err, result){return next(err, {c:[0,2,4]}[attr]);}}}},['a','b','c',2], next)
	#
	get: (obj, path, remove) ->
		# path as array specifies drilldown steps
		if _.isArray path
			if remove
				[path..., name] = path
				orig = obj
				for part, index in path
					obj = obj and obj[decodeURIComponent part]
				delete obj[name] if obj?[name]
				orig
			else
				for part in path
					obj = obj and obj[decodeURIComponent part]
				obj
		# no path means no drill
		else if path is undefined
			obj
		# ordinal path means one drilldown step
		else
			if remove
				delete obj[decodeURIComponent path]
				obj
			else
				obj[decodeURIComponent path]

	###
	# kick off properties mentioned in fields from obj
	# _.veto {a:{b:{c:'d',e:'f'}}}, ['a','b','e']} --> {a:{b:{c:'d'}}}
	veto: (obj, fields...) ->
		for k in fields
			if _.isString k
				delete obj[k] if obj
			else if _.isArray k
				k1 = k.shift()
				v1 = obj[k1]
				if _.isArray v1
					obj[k1] = v1.map (x) -> _.veto(x, if k.length > 1 then [k] else k)
				else if v1
					obj[k1] = _.veto(v1, if k.length > 1 then [k] else k)
		obj
	###
