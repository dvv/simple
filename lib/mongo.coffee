'use strict'

#
# Storage
#

nop = () -> console.log.apply console, ['STORE'].concat arguments

Database = require('mongo').Database
events = require 'events'

class Storage extends events.EventEmitter

	constructor: (options) ->
		options ?= {}
		@db = new Database options.url, hex: true
		@filterBy = options.filterBy
		@events = options.events

	insert: (collection, document, next) ->
		next ?= nop
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		# add history line
		document._meta =
			history: [
				who: document._meta?.creator
				when: Date.now()
				# FIXME: should we put initial document here?
			]
		self = @
		@db.insert collection, document, (err, result) ->
			if err
				err = 'Duplicated' if err.code is 11000
				err = err.message if err.code
			else
				result.id = result._id
				delete result._id
			if self.events is true or self.events?.add
				self.emit 'add',
					collection: collection
					result: document
					error: err
			next err, result

	update: (collection, query, changes, next) ->
		next ?= nop
		changes ?= {}
		#console.log 'UPDATE?', changes
		# add history line
		history =
			who: changes._meta.modifier
			when: Date.now()
		delete changes._meta
		history.what = changes
		query = _.rql(query).toMongo()
		search = query.search
		search.$atomic = 1
		# ensure changes are in multi-update format
		# FIXME: should prohibit $set and id in changes at facet level!!!
		changes = $set: changes #unless changes.$set or changes.$unset
		changes.$push = '_meta.history': history
		#console.log 'UPDATE!', changes
		self = @
		@db.update collection, search, changes, (err, result) ->
			if self.events is true or self.events?.update
				self.emit 'update',
					collection: collection
					search: search
					changes: changes
					result: result
					error: err?.message
			next err?.message

	find: (collection, query, next) ->
		next ?= nop
		#console.log 'FIND?', query
		query = _.rql(query)
		return next query.error if query.error
		#console.log 'FIND!', query.search
		query = query.toMongo()
		#console.log 'FIND!!', query
		# limit the limit
		#query.meta.limit = @limit if @limit < query.meta.limit
		self = @
		@db.find collection, query.search, query.meta, (err, result) ->
			#console.log 'FOUND', arguments
			for doc, i in result
				doc.id = doc._id
				delete doc._id
				if query.meta.toArray
					result[i] = _.toArray doc
			if self.events is true or self.events?.find
				self.emit 'find',
					collection: collection
					search: query.search
					result: result
					error: err?.message
			next err?.message, result

	findOne: (collection, query, next) ->
		next ?= nop
		#console.log 'FONE???', collection, query
		query = _.rql(query)
		return next query.error if query.error
		query = query.toMongo()
		#console.log 'FONE?', query
		self = @
		@db.findOne collection, query.search, query.meta, (err, result) ->
			#console.log 'FONE!', next
			if result
				result.id = result._id
				delete result._id
			else
				result = null
			if self.events is true or self.events?.findOne
				self.emit 'findOne',
					collection: collection
					search: query.search
					result: result
					error: err?.message
			next err?.message, result

	get: (collection, id, next) ->
		next ?= nop
		return next null, null unless id
		@findOne collection, _.rql().eq('id',id), next

	remove: (collection, query, next) ->
		next ?= nop
		query = _.rql(query).toMongo()
		# naive fuser
		return next 'Refuse to remove all documents w/o conditions' unless Object.keys(query.search).length
		#console.log 'REMOVE', query
		self = @
		@db.remove collection, query.search, (err, result) ->
			if self.events is true or self.events?.remove
				self.emit 'remove',
					collection: collection
					search: query.search
					result: result
					error: err?.message
			next err?.message, result

module.exports =
	Storage: Storage
