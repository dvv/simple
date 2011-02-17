###

     Vladimir Dronnikov 2011 dronnikov@gmail.com

     Redistribution and use in source and binary forms, with or without
     modification, are permitted provided that the following conditions are
     met:
     
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above
       copyright notice, this list of conditions and the following disclaimer
       in the documentation and/or other materials provided with the
       distribution.
     * Neither the name of the  nor the names of its
       contributors may be used to endorse or promote products derived from
       this software without specific prior written permission.
     
     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
     A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
     OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
     SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
     LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
     DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
     THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
     (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
     OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

###

# TODO: as a separate lib

_.mixin

	#
	# naive check if `value` is an object
	#
	isObject: (value) ->
		value and typeof value is 'object'

	#
	# ensure passed `value` is an array
	# make the array of the single item `value` otherwise
	#
	ensureArray: (value) ->
		return (if value is undefined then [] else [value]) unless value
		return [value] if _.isString value
		_.toArray value

	#
	# converts a `list` of objects to hash keyed by `field` in objects
	#
	toHash: (list, field) ->
		r = {}
		_.each list, (x) ->
			f = _.get x, field
			r[f] = x
		r

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
	# _.proxy {action: (x) -> DATA, private_stuff: ...}, ['action'] ---> {action: (x) -> DATA}
	# _.proxy {deep: {action: (x) -> DATA, private_stuff: ...}}, [['deep','action']] ---> {action: (x) -> DATA}
	# _.proxy {deep: {action: (x) -> DATA, private_stuff: ...}}, [[['deep','action'], 'allowed']] ---> {allowed: (x) -> DATA}
	# _.proxy {private_stuff: ...}, [[console.log, 'allowed']] ---> {allowed: console.log}
	#
	proxy: (obj, exposes) ->
		facet = {}
		_.each exposes, (definition) ->
			if _.isArray definition
				name = definition[1]
				prop = definition[0]
				prop = _.get obj, prop unless _.isFunction prop
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
					obj = obj and obj[part]
				# TODO: splice for arrays when path is number?
				delete obj[name] if obj?[name]
				orig
			else
				for part in path
					# FIXME: ?should delegate to _.get obj, part
					obj = obj and obj[part]
				obj
		# no path means no drill
		else if path is undefined
			obj
		# ordinal path means one drilldown step
		else
			if remove
				# TODO: splice for arrays when path is number?
				delete obj[path]
				obj
			else
				obj[path]

_.mixin
	#
	# until every engine supports ECMA5, safe coercing to Date is evil
	#
	parseDate: (value) ->
		date = new Date value
		return date if _.isDate date
		parts = String(value).match /(\d+)/g
		new Date(parts[0], ((parts[1] or 1) - 1), (parts[2] or 1))
	isDate: (obj) ->
		not not (obj?.getTimezoneOffset and obj.setUTCFullYear and not _.isNaN(obj.getTime()))
