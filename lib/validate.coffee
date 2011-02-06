###
	JSONSchema Validator - Validates JavaScript objects using JSON Schemas
	(http://www.json.com/json-schema-proposal/)

	Copyright (c) 2007 Kris Zyp SitePen (www.sitepen.com)
	Copyright (c) 2011 Vladimir Dronnikov dronnikov@gmail.com

	Licensed under the MIT (MIT-LICENSE.txt) license
###

#
# TODO: relax "readonly" complexity
#

#
# N.B. since we allow "enum" attribute to be async, the whole validator is treated as async if callback is specified
#
module.exports = (instance, schema, options = {}, callback) ->

	# FIXME: what it is?
	_changing = options.changing

	# pending validators
	asyncs = []

	# collected errors
	errors = []

	# validate a value against a property definition
	checkProp = (value, schema, path, i) ->

		if path
			if typeof i == 'number'
				path += '[' + i + ']'
			else if typeof i == 'undefined'
				path += ''
			else
				path += '.' + i
		else
			path += i

		addError = (message) ->
			errors.push property: path, message: message

		if (typeof schema isnt 'object' or _.isArray schema) and (path or typeof schema isnt 'function') and not schema?.type
			if typeof schema is 'function'
				if value not instanceof schema
					addError 'type'
			else if schema
				addError 'invalid'
			return null

		if _changing and schema.readonly
			addError 'readonly'

		if schema.extends # if it extends another schema, it must pass that schema as well
			checkProp value, schema.extends, path, i

		# validate a value against a type definition
		checkType = (type, value) ->
			if type
				if typeof type is 'string' and type isnt 'any' and
						`(type == 'null' ? value !== null : typeof value != type) &&
						!(value instanceof Array && type == 'array') &&
						!(value instanceof Date && type == 'date') &&
						!(type == 'integer' && value%1===0)`
					return [property: path, message: 'type']
				if _.isArray type
					# a union type
					unionErrors = []
					for t in type
						unionErrors = checkType t, value
						break unless unionErrors.length
					return unionErrors if unionErrors.length
				else if typeof type is 'object'
					priorErrors = errors
					errors = []
					checkProp value, type, path
					theseErrors = errors
					errors = priorErrors
					return theseErrors
			[]

		if value is undefined
			if (not schema.optional or typeof schema.optional is 'object' and not schema.optional[options.flavor]) and not schema.get and not schema.default?
				addError 'required'
		else
			errors = errors.concat checkType schema.type, value
			if schema.disallow and not checkType(schema.disallow,value).length
				addError 'disallowed'
			if value isnt null
				if _.isArray value
					if schema.items
						itemsIsArray = _.isArray schema.items
						propDef = schema.items
						for v, i in value
							if itemsIsArray
								propDef = schema.items[i]
							if options.coerce
								value[i] = options.coerce v, propDef.type
							errors.concat checkProp v, propDef, path, i
					if schema.minItems and value.length < schema.minItems
						addError 'minItems'
					if schema.maxItems and value.length > schema.maxItems
						addError 'maxItems'
				else if schema.properties or schema.additionalProperties
					errors.concat checkObj value, schema.properties, path, schema.additionalProperties
				if typeof value is 'string'
					if schema.pattern and not value.match schema.pattern
						addError 'pattern'
					if schema.maxLength and value.length > schema.maxLength
						addError 'maxLength'
					if schema.minLength and value.length < schema.minLength
						addError 'minLength'
				if typeof schema.minimum isnt undefined and typeof value is typeof schema.minimum and schema.minimum > value
					addError 'minimum'
				if typeof schema.maximum isnt undefined and typeof value is typeof schema.maximum and schema.maximum < value
					addError 'maximum'
				if schema.enum
					enumeration = schema.enum
					# if function specified, distinguish between async and sync flavors
					if typeof enumeration is 'function'
						# async validator
						if enumeration.length is 2
							asyncs.push value: value, path: path, fetch: enumeration
						# sync getter
						else
							enumeration = enumeration()
							addError 'enum' unless _.include enumeration, value
					else
						# simple array
						addError 'enum' unless _.include enumeration, value
				if typeof schema.maxDecimal is 'number' and (value.toString().match(new RegExp("\\.[0-9]{" + (schema.maxDecimal + 1) + ",}")))
					addError 'digits'
		null

	# validate an object against a schema
	checkObj = (instance, objTypeDef, path, additionalProp) ->

		if typeof objTypeDef is 'object'
			if typeof instance isnt 'object' or _.isArray instance
				errors.push property: path, message: 'type'
			for own i, propDef of objTypeDef
				value = instance[i]
				# skip _not_ specified properties
				continue if value is undefined and options.existingOnly
				# veto readonly props
				if options.vetoReadOnly and (propDef.readonly is true or typeof propDef.readonly is 'object' and propDef.readonly[options.flavor])
					delete instance[i]
					continue
				# done with validation if it is called for 'get'
				continue if options.flavor is 'get'
				# set default if validation called for 'add'
				if value is undefined and propDef.default? and options.flavor is 'add'
					value = instance[i] = propDef.default
				# coerce if coercion is enabled
				if options.coerce and i of instance
					value = options.coerce value, propDef.type
					instance[i] = value
				checkProp value, propDef, path, i

		for i, value of instance
			if instance.hasOwnProperty(i) and objTypeDef and not objTypeDef[i] and (additionalProp is false or options.removeAdditionalProps)
				if options.removeAdditionalProps
					delete instance[i]
					continue
				else
					errors.push property: path, message: 'unspecifed'
			requires = objTypeDef?[i]?.requires
			if requires and not requires of instance
				errors.push property: path, message: 'requires'
			if additionalProp and (not (objTypeDef and typeof objTypeDef is 'object') or not (i of objTypeDef))
				if options.coerce
					value = options.coerce value, additionalProp.type
					instance[i] = value
				checkProp value, additionalProp, path, i
			if not _changing and value?.$schema
				errors = errors.concat checkProp value, value.$schema, path, i
		errors

	if schema
		checkProp instance, schema, '', _changing or ''

	if not _changing and instance?.$schema
		checkProp instance, instance.$schema, '', ''

	# run async validators, if any
	len = asyncs.length
	if callback and len
		# N.B. 'this' contains valuable context
		context = @
		for async, i in asyncs
			do (async) ->
				async.fetch.call context, async.value, (err) ->
					if err
						errors.push property: async.path, message: 'enum'
					len -= 1
					# proceed when async validators are done
					unless len
						callback errors.length and errors or null, instance
	else if callback
		callback errors.length and errors or null, instance
	else
		return errors.length and errors or null

	return
