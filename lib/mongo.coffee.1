'use strict'

# valid funcs
valid_funcs = ['lt', 'lte', 'gt', 'gte', 'ne', 'in', 'nin', 'not', 'mod', 'all', 'size', 'exists', 'type', 'elemMatch']
# funcs which definitely require array arguments
requires_array = ['in', 'nin', 'all', 'mod']
# funcs acting as operators
valid_operators = ['or', 'and', 'not'] #, 'xor']

parse = (query) ->

	options = {}
	search = {}

	walk = (name, terms) ->
		search = {} # compiled search conditions
		# iterate over terms
		(terms or []).forEach (term) ->
			term ?= {}
			func = term.name
			args = term.args
			# ignore bad terms
			# N.B. this filters quirky terms such as for ?or(1,2) -- term here is a plain value
			return unless func and args
			# http://www.mongodb.org/display/DOCS/Querying
			# nested terms? -> recurse
			if args[0] instanceof Query
				if 0 <= valid_operators.indexOf func
					search['$'+func] = walk func, args
				# N.B. here we encountered a custom function
				# ...
			# http://www.mongodb.org/display/DOCS/Advanced+Queries
			# structured query syntax
			else
				if func is 'le'
					func = 'lte'
				else if func is 'ge'
					func = 'gte'
				# args[0] is the name of the property
				key = args.shift()
				key = key.join('.') if Array.isArray key
				# prohibit keys started with $
				return if key.charAt(0) is '$'
				# the rest args are parameters to func()
				if 0 <= requires_array.indexOf func
					args = args[0]
				# match on regexp means equality
				else if func is 'match'
					func = 'eq'
					regex = new RegExp
					regex.compile.apply regex, args
					args = regex
				else
					# FIXME: do we really need to .join()?!
					args = if args.length is 1 then args[0] else args.join()
				# regexp inequality means negation of equality
				func = 'not' if func is 'ne' and args instanceof RegExp
				# valid functions are prepended with $
				func = '$'+func if 0 <= valid_funcs.indexOf func
				# $or requires an array of conditions
				if name is 'or'
					search = [] unless Array.isArray search
					x = {}
					x[if func is 'eq' then key else func] = args
					search.push x
				# other functions pack conditions into object
				else
					# several conditions on the same property are merged into the single object condition
					search[key] = {} if search[key] is undefined
					search[key][func] = args if search[key] instanceof Object and not Array.isArray search[key]
					# equality cancels all other conditions
					search[key] = args if func is 'eq'
		# TODO: add support for query expressions as Javascript
		# TODO: add support for server-side functions
		search

	# FIXME: parseQuery of normalized query should be idempotent!!!
	# TODO: more robustly determine already normal query!
	# TODO: RQL as executor: Query().le(a,1).fetch() <== real action
	query = parseQuery(query).normalize({primaryKey: '_id'}) unless query?.sortObj
	search = walk query.search.name, query.search.args
	options.sort = query.sortObj if query.sortObj
	options.fields = query.selectObj if query.selectObj
	if query.limit
		options.limit = query.limit[0]
		options.skip = query.limit[1]
	#console.log meta: options, search: search, terms: query
	meta: options, search: search, terms: query

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
		query = parse query
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
		query = parse query
		#console.log 'FIND!', query.search
		return next query.terms.search.error if query.terms.search.error
		# limit the limit
		#query.meta.limit = @limit if @limit < query.meta.limit
		self = @
		@db.find collection, query.search, query.meta, (err, result) ->
			#console.log 'FOUND', arguments
			for doc, i in result
				doc.id = doc._id
				delete doc._id
			if self.events is true or self.events?.find
				self.emit 'find',
					collection: collection
					search: query.search
					result: result
					error: err?.message
			next err?.message, result

	findOne: (collection, query, next) ->
		next ?= nop
		query = parse query
		#console.log 'FONE?', query
		return next query.terms.search.error if query.terms.search.error
		self = @
		@db.findOne collection, query.search, query.meta, (err, result) ->
			#console.log 'FONE!', arguments
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
		@findOne collection, "id=#{id}", next
		#console.log 'GET', id
		#@findOne collection, Query('id',id), next

	remove: (collection, query, next) ->
		next ?= nop
		query = parse query
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
