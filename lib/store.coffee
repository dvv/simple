'use strict'

#
# Schema
#
_validate = require './validate'
global.validate = (instance, schema, options, next) -> _validate instance, schema, _.extend(options or {}, coerce: _.coerce), next

#
# Storage
#

storage = null

module.exports = (options) ->
	options ?= {}
	storage = new (require('./mongo').Storage) options
	Object.freeze
		onevent: storage.on.bind storage
		Store: Store
		SecuredStore: SecuredStore
		Model: Model
		Facet: Facet
		RestrictiveFacet: RestrictiveFacet
		PermissiveFacet: PermissiveFacet

#
# Store -- set of DB accessor methods for a particular collection, bound to the db and the collection
#
Store = (entity) ->
	store =
		query: storage.find.bind storage, entity
		one: storage.findOne.bind storage, entity
		get: storage.get.bind storage, entity
		add: storage.insert.bind storage, entity
		update: storage.update.bind storage, entity
		remove: storage.remove.bind storage, entity
	Object.defineProperty store, 'id', value: entity
	store

#
# put validating logic
# - passed documents must obey schema's update/add flavors
# - returned documents are filtered by schema's get flavor
#
SecuredStore = (store, schema) ->

	filterBy = storage.filterBy #'active' # FIXME: dehardcode!!!

	secured =

		add: (document, next) ->
			self = @
			document ?= {}
			Step(
				() ->
					#console.log 'BEFOREADD', document #, schema
					# validate document
					if schema
						validate document, schema, {vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'add'}, @
						return
					else
						document
				(err, document) ->
					#console.log 'ADDDDD', arguments
					if err
						next err
						return
					if filterBy
						document[filterBy] = true
					# update meta
					document._meta =
						creator: self?.user?.id
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
			)

		update: (query, changes, next) ->
			self = @
			changes ?= {}
			Step(
				() ->
					#console.log 'BEFOREUPDATE', query, changes, schema
					# validate document
					if schema
						validate changes, schema, {vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, existingOnly: true, flavor: 'update'}, @
						return
					else
						changes
				(err, changes) ->
					#console.log 'BEFOREUPDATEVALIDATED', arguments
					if err
						next err
						return
					# N.B. shortcut on empty changes
					#console.log 'BEFOREUPDATEVALIDATED', query, changes
					unless _.keys changes
						next()
						return
					# update meta
					changes._meta =
						modifier: self?.user?.id
					# update documents
					store.update query, changes, @
				(err, result) ->
					#console.log 'AFTERUPDATE', arguments
					next err, result
			)

		#updateOwn: (query, changes, next) ->
		#	secured.update.call @, _.rql(query).eq('_meta.history.0.who', @ and @user?.id), changes, next

		query: (query, next) ->
			console.log 'FIND?', query
			if filterBy
				query = _.rql(query).eq(filterBy,true)
			console.log 'FIND!', query
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
		#	secured.query.call @, _.rql(query).eq('_meta.history.0.who', @ and @user?.id), next

		one: (query, next) ->
			if filterBy
				query = _.rql(query).eq(filterBy,true)
			#console.log 'FONE?', query
			store.one query, (err, result) ->
				#console.log 'FONE!', arguments
				if err
					next err
					return
				result ?= null
				# filter out protected fields
				if schema and result
					validate result, schema, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
				next null, result

		get: (id, next) -> secured.one.call @, _.rql().eq('id',id), next
		_get: (id, next) -> store.get id, next

		remove: (query, next) ->
			if filterBy
				query = _.rql(query).eq(filterBy,true)
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
				query = _.rql(query).ne(filterBy,true)
			store.remove query, (err, result) ->
				next err, result

		undelete: (query, next) ->
			if filterBy
				query = _.rql(query).ne(filterBy,true)
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
			if context?.user?.id then _.rql(query).eq('_meta.history.0.who', context?.user?.id) else _.rql(query)

	secured

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
	Object.freeze _.extend.apply {}, [store].concat overrides


#########################################

#
# Model -- set of overloaded Store methods plus business logic
#

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
		if _.isArray definition
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
	Facet model, options, ['query', 'get', 'add', 'update', 'remove'].concat(expose or [])

# expose only collection _getters_ plus enlisted model methods
RestrictiveFacet = (model, options, expose...) ->
	Facet model, options, ['query', 'get'].concat(expose or [])
