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
	Object.freeze
		onevent: storage.on.bind storage
		Store: Store0
		applySchema: applySchema

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

#
# put validating logic
# - passed documents must obey schema's update/add flavors
# - returned documents are filtered by schema's get flavor
#
applySchema = (store, schema) ->

	filterBy = storage.filterBy #'active' # FIXME: dehardcode!!!

	self =

		add: (document, next) ->
			document ?= {}
			#console.log 'BEFOREADD', document, schema
			# validate document
			if schema
				validation = validate document, schema, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'add'
				if not validation.valid
					next validation.errors
					return
			if filterBy
				document[filterBy] = true
			# update meta
			document._meta =
				creator: @ and @user?.id
			# insert document
			store.add document, (err, result) ->
				if err
					next err
					return
				#console.log 'AFTERADD', arguments
				# filter out protected fields
				if schema
					validate result, schema, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
				next null, result

		update: (query, changes, next) ->
			changes ?= {}
			#console.log 'BEFOREUPDATE', query, changes, schema
			# validate document
			if schema
				validation = validate changes, schema, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, existingOnly: true, flavor: 'update'
				if not validation.valid
					next validation.errors
					return
			# update meta
			changes._meta =
				modifier: @ and @user?.id
			#console.log 'BEFOREUPDATEVALIDATED', changes
			# update documents
			store.update query, changes, (err, result) ->
				#console.log 'AFTERUPDATE', arguments
				next err, result

		#updateOwn: (query, changes, next) ->
		#	self.update.call @, Query(query).eq('_meta.history.0.who', @ and @user?.id), changes, next

		query: (query, next) ->
			if filterBy
				query = parseQuery(query).eq(filterBy,true)
			store.query query, (err, result) ->
				#console.log 'FOUND', arguments
				if err
					next err
					return
				# filter out protected fields
				if schema
					for doc, k in result
						validate doc, schema, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
				next null, result

		#queryOwn: (query, next) ->
		#	self.query.call @, Query(query).eq('_meta.history.0.who', @ and @user?.id), next

		one: (query, next) ->
			if filterBy
				query = parseQuery(query).eq(filterBy,true)
			store.one query, (err, result) ->
				#console.log 'FONE!', query, arguments
				if err
					next err
					return
				result ?= null
				# filter out protected fields
				if schema and result
					validate result, schema, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
				next null, result

		get: (id, next) -> self.one.call @, Query('id',id), next
		_get: (id, next) -> store.get id, next

		remove: (query, next) ->
			if filterBy
				query = parseQuery(query).eq(filterBy,true)
				changes = {}
				changes[filterBy] = false
				# update meta
				changes._meta =
					modifier: @ and @user?.id
				# update documents
				store.update query, changes, (err, result) ->
					next err, result
			else
				store.remove query, (err, result) ->
					next err, result

		delete: (query, next) ->
			store.remove query, (err, result) ->
				next err, result

		purge: (query, next) ->
			if filterBy
				query = parseQuery(query).ne(filterBy,true)
			store.remove query, (err, result) ->
				next err, result

		undelete: (query, next) ->
			if filterBy
				query = parseQuery(query).ne(filterBy,true)
				changes = {}
				changes[filterBy] = true
				# update meta
				changes._meta =
					modifier: @ and @user?.id
				# update documents
				store.update query, changes, (err, result) ->
					next err, result
			else
				next 'Not implemented'

		owned: (context, query) ->
			if context?.user?.id then Query(query).eq('_meta.history.0.who', context?.user?.id) else Query(query)

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
