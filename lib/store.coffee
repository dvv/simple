'use strict'

#
# Schema
#
Schema = require 'json-schema/lib/validate'
validate = (instance, schema, options) -> Schema._validate instance, schema, U.extend(options or {}, coerce: U.coerce)

#
# Storage
#

storage = null

module.exports = (options) ->
	options ?= {}
	storage = new (require('./mongo').Storage) options
	{
		Store: Store0
		applySchema: applySchema
	}

#
# Store -- set of DB accessor methods for a particular collection, bound to the db and the collection
#
Store0 = (entity) ->
	store =
		query: storage.find.bind storage, entity
		one: storage.findOne.bind storage, entity
		get: storage.get.bind storage, entity
		add: storage.insert.bind storage, entity
		update: storage.update.bind storage, entity
		remove: storage.remove.bind storage, entity
	Object.defineProperty store, 'id', value: entity
	store

class Store
	constructor: (entity) ->
		@query = storage.find.bind storage, entity
		@one = storage.findOne.bind storage, entity
		@get = storage.get.bind storage, entity
		@add = storage.insert.bind storage, entity
		@update = storage.update.bind storage, entity
		@remove = storage.remove.bind storage, entity
		Object.defineProperty @, 'id', value: entity
	where: (query) ->
		@_query = parseQuery query
		Object.defineProperty @_query, 'remove', value: () -> @remove @_query
		Object.defineProperty @_query, 'update', value: (changes) -> @update @_query, changes
		Object.defineProperty @_query, 'all', value: () -> @query @_query
		Object.defineProperty @_query, 'one', value: () -> @one @_query
		@_query

applySchema = (store, schema) ->
	add: (document, next) ->
		document ?= {}
		if schema
			#console.log 'BEFOREADD', document, schema
			validation = validate document, schema, vetoReadOnly: true, flavor: 'add'
			if not validation.valid
				return next SyntaxError JSON.stringify validation.errors
		store.add document, (err, result) ->
			return next err if err
			if schema
				validate result, schema, vetoReadOnly: true, flavor: 'get'
			next null, result
	update: (query, changes, next) ->
		changes ?= {}
		if schema
			validation = validate changes, schema, vetoReadOnly: true, existingOnly: true, flavor: 'update'
			if not validation.valid
				return next SyntaxError JSON.stringify validation.errors
		store.update query, changes, (err, result) ->
			return next err if err
			next()
	query: (query, next) ->
		store.query query, (err, result) ->
			#console.log 'FOUND', arguments
			return next err if err
			if schema
				for k, doc in result
					validate doc, schema, vetoReadOnly: true, flavor: 'get'
			next null, result
	one: (query, next) ->
		store.one query, (err, result) ->
			#console.log 'FONE!', query, arguments
			return next err if err
			result ?= null
			if schema and result
				validate result, schema, vetoReadOnly: true, flavor: 'get'
			next null, result
	get: (id, next) ->
		store.get id, (err, result) ->
			#console.log 'GOT!', query, arguments
			return next err if err
			result ?= null
			if schema and result
				validate result, schema, vetoReadOnly: true, flavor: 'get'
			next null, result
	remove: (query, next) ->
		store.remove query, (err, result) ->
			return next err if err
			next()

#########################################

#
# Store -- set of DB accessor methods ###bound to the db and the collection and the optional schema
#
Model = (db, entity, options, overrides...) ->
	options ?= {}
	storage = Store db, entity, options.schema
	store =
		all: storage.find.bind storage, entity, options.schema
		_all: storage.find.bind storage, entity
		one: storage.findOne.bind storage, entity, options.schema
		get: storage.get.bind storage, entity, options.schema
		_get: storage.get.bind storage, entity
		add: storage.insert.bind storage, entity, options.schema
		_add: storage.insert.bind storage, entity
		update: storage.update.bind storage, entity, options.schema
		_update: storage.update.bind storage, entity
		remove: storage.remove.bind storage, entity
	Object.defineProperty store, 'id', value: entity
	Object.defineProperty store, 'schema', value: options.schema
	Object.freeze Compose.create.apply Compose, [store].concat overrides


#########################################

#
# Model -- set of overloaded Store methods plus business logic
#
'''
Model = (entity, store, options, overrides) ->
	model = Compose.create store or Store(entity, options), overrides
	Object.defineProperty model, 'where', value: (query) ->
		q = parseQuery query
		Object.defineProperty q, 'add', value: (doc) -> model.add q, doc
		Object.defineProperty q, 'remove', value: () -> model.remove q
		Object.defineProperty q, 'update', value: (changes) -> model.update q, changes
		Object.defineProperty q, 'all', value: () -> model.all q
		Object.defineProperty q, 'one', value: () -> model.one q
		q
	Object.freeze model
Model = Store
'''

#########################################

#
# Facet -- exposed flat list of SecuredModel methods
#

# expose enlisted model methods
Facet = (model, options, expose) ->
	options ?= {}
	facet = {}
	facet.schema = model.schema if model.schema
	expose and expose.forEach (definition) ->
		if Array.isArray definition
			name = definition[1]
			method = definition[0]
			method = model[method] if typeof method is 'string'
		else
			name = definition
			method = model[name]
		#
		facet[name] = method if method
	Object.freeze facet

# expose collection accessors plus enlisted model methods
PermissiveFacet = (model, options, expose...) ->
	Facet model, options, ['all', 'get', 'add', 'update', 'remove'].concat(expose or [])

# expose only collection _getters_ plus enlisted model methods
RestrictiveFacet = (model, options, expose...) ->
	Facet model, options, ['all', 'get'].concat(expose or [])

#########################################

'''
module.exports =
	Store: Store
	Model: Model
	Facet: Facet
	RestrictiveFacet: RestrictiveFacet
	PermissiveFacet: PermissiveFacet
'''
