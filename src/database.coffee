'use strict'

parseUrl = require('url').parse
mongo = require 'mongodb'
events = require 'events'

class Database extends events.EventEmitter

	constructor: (options = {}, definitions, callback) ->
		# we connect by URL
		conn = parseUrl options.url or ''
		host = conn.hostname
		port = +conn.port if conn.port
		@auth = conn.auth if conn.auth # FIXME: should not sit in @
		name = conn.pathname.substring(1) if conn.pathname
		# cache of collections
		@collections = {}
		# model -- collection of registered entities
		@model = {}
		# primary key factory
		@idFactory = () -> (new mongo.BSONPure.ObjectID).toHexString()
		# attribute to be used to mark document as deleted
		# N.B. it allows for 3 additional methods: delete/undelete/purge
		@attrInactive = options.attrInactive #'_deleted'
		# DB connection
		@db = new mongo.Db name or 'test', new mongo.Server(host or '127.0.0.1', port or 27017) #, native_parser: true
		# register schema
		@open definitions, callback if definitions

	###########
	# N.B. all methods should return undefined, so to prevent leak of private info
	###########

	#
	# connect to DB, optionally authenticate, cache collections named after `collections[]`
	#
	#
	# FIXME: we already have this in the driver?!
	#
	open: (collections, callback) ->
		self = @
		self.db.open (err, result) ->
			if self.auth
				[username, password] = self.auth.split ':', 2
				self.db.authenticate username, password, (err, result) ->
					return callback? err.message if err
					self.register collections, callback
			else
				return callback? err.message if err
				self.register collections, callback
		return

	register: (schema, callback) ->
		self = @
		len = _.size schema
		for name, definition of schema
			do (name) ->
				self.db.collection name, (err, coll) ->
					self.collections[name] = coll
					# TODO: may init indexes here
					# ...
					# model
					store = self.Entity name, definition
					# extend the store
					if definition?.prototype
						for own k, v of definition.prototype
							store[k] = if _.isFunction v then v.bind store else v
						delete definition.prototype
					# define identification
					Object.defineProperties store,
						id:
							value: name
						schema:
							value: definition
					# register model
					self.model[name] = store
					# all done?
					if --len <= 0
						callback? err?.message, self.model
				return
		return

	#
	# return the list of documents matching `query`; attributes are filtered by optional `schema`
	#
	query: (collection, schema, context, query, callback) ->
		#console.log 'FIND??', query, @attrInactive
		query = _.rql(query)
		# skip documents marked as deleted
		if @attrInactive
			query = query.ne(@attrInactive,true)
		#console.log 'FIND?', query
		query = query.toMongo()
		#console.log 'FIND!', query
		@collections[collection].find query.search, query.meta, (err, cursor) ->
			return callback? err.message if err
			cursor.toArray (err, docs) ->
				#console.log 'FOUND', arguments
				return callback? err.message if err
				for doc, i in docs
					# _id -> id
					doc.id = doc._id
					delete doc._id
					# filter out protected fields
					if schema
						_.validate doc, schema, veto: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
				docs = _.map docs, _.values if query.meta.values
				callback? null, docs
		return

	#
	# return the first documents matching `id`; attributes are filtered by optional `schema`
	# N.B. internally uses @query
	#
	get: (collection, schema, context, id, callback) ->
		query = _.rql('limit(1)').eq('id',id)
		# N.B. if id is array -- what to do?
		@query collection, schema, context, query, (err, result) ->
			if callback
				if err
					callback err.message
				else
					callback null, result[0] or null
		return

	#
	# generate query to filter only documents owned by the context user or his subordinates
	#
	owned: (context, query) ->
		if context?.user?.id then _.rql(query).eq('_meta.history.0.who', context?.user?.id) else _.rql(query)

	#
	# insert new `document` validated by optional `schema`
	#
	add: (collection, schema, context, document = {}, callback) ->
		self = @
		user = context?.user?.id
		# assign new primary key unless specified
		document.id = @idFactory() unless document.id
		Next self,
			(err, result, next) ->
				#console.error 'BEFOREADD', document, schema
				# validate document
				if schema
					_.validate.call context, document, schema, {veto: true, removeAdditionalProps: not schema.additionalProperties, flavor: 'add', coerce: true}, next
				else
					next null, document
			(err, document, next) ->
				#console.error 'ADDVALIDATED', arguments
				return next err if err
				# id -> _id
				document._id = document.id
				delete document.id
				# add history line
				#console.log 'CREATOR', user, context?.user?._meta?.history?[0].who
				parents = context?.user?._meta?.history?[0].who or []
				parents.unshift user
				document._meta =
					history: [
						who: parents
						when: Date.now()
						# FIXME: should we put initial document here?
					]
				# do add
				@collections[collection].insert document, {safe: true}, next
			(err, result, next) ->
				#console.error 'ADD', arguments
				if err
					if err.message?.substring(0,6) is 'E11000'
						err = [{property: 'id', message: 'duplicated'}]
					callback? err
					#self.emit 'add',
					#	collection: collection
					#	user: user
					#	error: err
				else
					result = result[0]
					result.id = result._id
					delete result._id
					# filter out protected fields
					if schema
						_.validate result, schema, veto: true, removeAdditionalProps: not schema.additionalProperties, flavor: 'get'
					callback? null, result
					#self.emit 'add',
					#	collection: collection
					#	user: user
					#	result: result
		return

	#
	# update documents matching `query` using `changes` partially validated by optional `schema`
	#
	update: (collection, schema, context, query, changes = {}, callback) ->
		self = @
		user = context?.user?.id
		# atomize the query
		query = _.rql(query).toMongo()
		query.search.$atomic = 1
		# add history line
		Next self,
			(err, result, next) ->
				#console.log 'BEFOREUPDATE', query, changes, schema
				# validate document
				if schema
					_.validate.call context, changes, schema, {veto: true, removeAdditionalProps: !schema.additionalProperties, existingOnly: true, flavor: 'update', coerce: true}, next
				else
					next null, changes
			(err, changes, next) ->
				#console.log 'BEFOREUPDATEVALIDATED', arguments
				# N.B. we inhibit empty changes
				return next err if err or not _.size changes
				history =
					who: user
					when: Date.now()
				delete changes._meta
				history.what = changes
				# ensure changes are in multi-update format
				# FIXME: should prohibit $set and id in changes at facet level!!!
				changes = $set: changes #unless changes.$set or changes.$unset
				changes.$push = '_meta.history': history
				# do multi update
				@collections[collection].update query.search, changes, {multi: true}, next
			(err, result) ->
				callback? err?.message or err
				#self.emit 'update',
				#	collection: collection
				#	user: user
				#	search: query.search
				#	changes: changes
				#	err: err?.message or err
				#	result: result
		return

	#
	# physically remove documents
	#
	remove: (collection, context, query, callback) ->
		self = @
		user = context?.user?.id
		query = _.rql(query).toMongo()
		# naive fuser
		return callback? 'Refuse to remove all documents w/o conditions' unless _.size query.search
		@collections[collection].remove query.search, (err) ->
			callback? err?.message
			#self.emit 'remove',
			#	collection: collection
			#	user: user
			#	search: query.search
			#	error: err?.message
		return

	#
	# mark documents as deleted if @attrInactive specified, or remove them unless
	#
	delete: (collection, context, query, callback) ->
		if @attrInactive
			query = _.rql(query).ne(@attrInactive,true).toMongo()
			# the only change is to set @attrInactive
			changes = {}
			changes[@attrInactive] = true
			# update documents
			@update collection, null, context, query.search, changes, callback
		else
			@remove collection, context, query, callback
		return

	#
	# clears documents' deleted mark
	#
	undelete: (collection, context, query, callback) ->
		if @attrInactive
			query = _.rql(query).eq(@attrInactive,true).toMongo()
			# the only change is to set @attrInactive
			changes = {}
			changes[@attrInactive] = false
			# update documents
			@update collection, null, context, query.search, changes, callback
		else
			callback?()
		return

	#
	# physically remove documents marked as deleted
	#
	purge: (collection, context, query, callback) ->
		if @attrInactive
			query = _.rql(query).eq(@attrInactive,true)
			@remove collection, context, query, callback
		else
			callback?()
		return

	#
	# Entity -- set of DB accessor methods for a particular collection,
	#			bound to the db and the collection and optional schema
	#
	Entity: (entity, schema) ->
		##@register [entity] # N.B. don't wait
		db = @
		# compose the store
		store =
			# un-schema-ed method -- should be for internal use only
			_query: db.query.bind db, entity
			_get: db.get.bind db, entity
			_add: db.add.bind db, entity
			_update: db.update.bind db, entity
			# owned helper
			owned: db.owned
			# safe accessors
			query: db.query.bind db, entity, schema
			get: db.get.bind db, entity, schema
			add: db.add.bind db, entity, schema
			update: db.update.bind db, entity, schema
			remove: db.remove.bind db, entity
		# special methods to support delayed deletion
		if @attrInactive
			_.extend store,
				delete: db.delete.bind db, entity
				undelete: db.undelete.bind db, entity
				purge: db.purge.bind db, entity
		store

module.exports = Database
