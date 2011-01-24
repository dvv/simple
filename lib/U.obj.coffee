# TODO: as a separate lib

# U.drill({a:{b:{c:[0,2,4]}}},['a','b','c',2]) ---> 4
# U.drill({a:{b:{get:function(attr){return{c:[0,2,4]}[attr];}}}},['a','b','c',2]) ---> 4
U.mixin
	drill: (obj, path) ->
		_drill = (obj, path) ->
			return obj unless obj and path?
			if U.isArray path
				U.each path, (part) ->
					obj = obj and _drill obj, part
				obj
			else if typeof path is 'undefined'
				obj
			else
				attr = if U.isNumber path then path else decodeURIComponent path
				# FIXME: false .get() in models, .get() requires wait()
				#obj.get and obj.get(attr) or obj[attr]
				obj[attr]
		_drill obj, path
	# kick off properties mentioned in fields from obj
	veto: (obj, fields) ->
		for k in fields
			if typeof k is 'string'
				delete obj[k] if obj
				#obj[k] = undefined
			else if k instanceof Array
				k1 = k.shift()
				v1 = obj[k1]
				if v1 instanceof Array
					obj[k1] = v1.map (x) -> U.veto(x, if k.length > 1 then [k] else k)
				else if v1
					obj[k1] = U.veto(v1, if k.length > 1 then [k] else k)
		obj
