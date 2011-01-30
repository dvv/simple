###
	JSONSchema Validator - Validates JavaScript objects using JSON Schemas
	(http://www.json.com/json-schema-proposal/)
	Copyright (c) 2007 Kris Zyp SitePen (www.sitepen.com)
Licensed under the MIT (MIT-LICENSE.txt) license.
To use the validator call the validate function with an instance object and an optional schema object.
If a schema is provided, it will be used to validate. If the instance object refers to a schema (self-validating),
that schema will be used to validate and the schema parameter is not necessary (if both exist,
both validations will occur).
The validate method will return an array of validation errors. If there are no errors, then an
empty list will be returned. A validation error will have two properties:
"property" which indicates which property had the error
"message" which indicates what the error was
###

module.exports = (instance, schema, options, callback) ->

	options ?= {}
	_changing = options.changing

	asyncs = []

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
					unionErrors = []
					for t in type # a union type
						break unless (unionErrors=checkType(t, value)).length
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
								value[i] = options.coerce v, propDef
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
					if typeof schema.enum is 'function'
						asyncs.push value: value, path: path, fetch: schema.enum
					else
						unless _.include schema.enum, value
							addError 'enum'
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
				# set default
				if value is undefined and propDef.default and options.flavor isnt 'get'
					value = instance[i] = propDef.default
				if options.coerce and i in instance
					value = instance[i] = options.coerce value, propDef
				checkProp value, propDef, path, i

		`
		for(i in instance){
			if(instance.hasOwnProperty(i) && objTypeDef && !objTypeDef[i] && (additionalProp===false || options.removeAdditionalProps)){
				if (options.removeAdditionalProps) {
					delete instance[i];
					continue;
				} else {
					errors.push({property:path,message:"unspecifed"});
				}
			}
			var requires = objTypeDef && objTypeDef[i] && objTypeDef[i].requires;
			if(requires && !(requires in instance)){
				errors.push({property:path,message:"requires"});
			}
			value = instance[i];
			if(additionalProp && (!(objTypeDef && typeof objTypeDef == 'object') || !(i in objTypeDef))){
				if(options.coerce){
					value = instance[i] = options.coerce(value, additionalProp);
				}
				checkProp(value,additionalProp,path,i);
			}
			if(!_changing && value && value.$schema){
				errors = errors.concat(checkProp(value,value.$schema,path,i));
			}
		}
		`
		errors

	if schema
		checkProp instance, schema, '', _changing or ''
	if not _changing and instance?.$schema
		checkProp instance, instance.$schema, '', ''

	len = asyncs.length
	if len
		while asyncs.length
			async = asyncs.pop()
			value = async.value
			async.fetch (err, values) ->
				unless _.include(values, value)
					errors.push property: async.path, message: 'enum'
				len -= 1
				unless len
					callback errors.length and errors or null, instance
	else
		callback errors.length and errors or null, instance
