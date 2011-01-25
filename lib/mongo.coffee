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
			return if not func or not args
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

class Storage

	constructor: (options) ->
		options ?= {}
		@db = new Database options.url, hex: true

	insert: (collection, document, next) ->
		next ?= nop
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		@db.insert collection, document, (err, result) ->
			if err
				err = SyntaxError 'Duplicated' if err.code is 11000
				err = SyntaxError err.message if err.code
				return next err
			result.id = result._id
			delete result._id
			next null, result

	update: (collection, query, changes, next) ->
		next ?= nop
		changes ?= {}
		query = parse query
		search = query.search
		search.$atomic = 1
		# ensure changes are in multi-update format
		# FIXME: can be security breach to not check for $set/$unset!
		# FIXME: OTOH -- it;s they way to bypass schema for authorized needs
		# FIXME: should prohibit $set and id in changes at facet level!!!
		changes = {$set: changes} unless changes.$set or changes.$unset
		@db.update collection, search, changes, (err, result) ->
			return next SyntaxError err.message if err
			next()

	find: (collection, query, next) ->
		next ?= nop
		#console.log 'FIND?', query
		query = parse query
		#console.log 'FIND!', query.search
		return next URIError query.terms.search.error if query.terms.search.error
		# limit the limit
		#query.meta.limit = @limit if @limit < query.meta.limit
		@db.find collection, query.search, query.meta, (err, result) ->
			#console.log 'FOUND', arguments
			return next URIError err.message if err
			for i, doc in result
				doc.id = doc._id
				delete doc._id
			next null, result

	findOne: (collection, query, next) ->
		next ?= nop
		query = parse query
		return next URIError query.terms.search.error if query.terms.search.error
		@db.findOne collection, query.search, query.meta, (err, result) ->
			#console.log 'FONE!', query, arguments
			return next URIError err.message if err
			result ?= null
			if result
				result.id = result._id
				delete result._id
			next null, result

	get: (collection, id, next) ->
		next ?= nop
		return next null, null unless id
		@findOne collection, "id=#{id}", next

	remove: (collection, query, next) ->
		next ?= nop
		query = parse query
		# naive fuser
		return next TypeError 'Use drop() instead to remove the whole collection' unless Object.keys(query.search).length
		@db.remove collection, query.search, (err, result) ->
			return next URIError err.message if err
			next()

module.exports =
	Storage: Storage
