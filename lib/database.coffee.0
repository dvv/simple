#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'
global._ = require 'underscore'

_.mixin
	rql: require('jse/rql').rql

inspect = require('eyes.js').inspector stream: null
consoleLog = console.log
console.log = () -> consoleLog inspect arg for arg in arguments

Next = (context, steps...) ->
	next = (err, result) ->
		unless steps.length
			throw err if err
			return
		fn = steps.shift()
		try
			fn.call context, err, result, next
		catch err
			next err
		return context
	next()

###
a = () -> Next {foo: 'bar'},
	(err, result, next) ->
		console.log 'first', arguments
		return next err if err
		#throw 'Catch me1!'
		next 'err1', 'res1'
	(err, result, next) ->
		console.log 'second', arguments
		return next err if err
		next 'err2', 'res2'
	(err, result, next) ->
		console.log 'third', arguments
		return next err if err
		next 'err3', 'res3'

try
	console.log 'A', a()
catch err
	console.log 'CAUGHT', err
###

parseUrl = require('url').parse
mongo = require 'mongodb'
events = require 'events'

#
# TODO:
# 3. schema

class Database extends events.EventEmitter

	constructor: (@url) ->
		conn = parseUrl @url
		@host = conn.hostname
		@port = +conn.port if conn.port
		@auth = conn.auth if conn.auth # FIXME: what is options analog?
		@name = conn.pathname.substring(1) if conn.pathname
		@collections = {}
		@idFactory = () ->
			(new mongo.BSONPure.ObjectID).toHexString()
		@db = new mongo.Db @name, new mongo.Server(@host, @port)

	open: (collections, callback) ->
		self = @
		register = (callback) ->
			len = collections.length
			for name in collections
				do (name) ->
					self.db.collection name, (err, coll) ->
						self.collections[name] = coll
						# TODO: may init indexes here
						# ...
						if --len <= 0
							callback err
		self.db.open (err, result) ->
			if self.auth
				[username, password] = self.auth.split ':', 2
				self.db.authenticate username, password, (err, result) ->
					return callback err if err
					register callback
			else
				return callback err if err
				register callback

	query: (collection, query, callback) ->
		query = _.rql(query).toMongo()
		#console.log 'FIND!', query
		@collections[collection].find query.search, query.meta, (err, cursor) ->
			return callback err if err
			cursor.toArray (err, docs) ->
				#console.log 'FOUND', arguments
				return callback err if err
				ta = query.meta.toArray
				for doc, i in docs
					doc.id = doc._id
					delete doc._id
					docs[i] = _.toArray doc if ta
				callback null, docs

	get: (collection, id, callback) ->
		@query collection, _.rql('limit(1)').eq('id',id), (err, result) ->
			return callback err if err
			callback null, result[0] or null

	add: (collection, document, callback) ->
		self = @
		# id -> _id
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
		# assign new _id unless specified
		document._id = @idFactory() unless document._id
		# do add
		@collections[collection].insert document, {safe: true}, (err, result) ->
			#console.log 'ADD', arguments
			if err
				if err.message.substring(0,6) is 'E11000'
					err.message = 'Duplicated'
				callback err.message
				#self.emit 'add',
				#	collection: collection
				#	error: err.message
			else
				result = result[0]
				result.id = result._id
				delete result._id
				callback null, result
				#self.emit 'add',
				#	collection: collection
				#	result: result

	###
	# FIXME: feasible to have?????
	#
	put: (collection, document, callback) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		# add history line
		document._meta =
			history: [
				who: document._meta?.modifier
				when: Date.now()
				# FIXME: should we put initial document here?
			]
		@collections[collection].update {_id: document._id}, document, (err, result) ->
			callback err
	###

	update: (collection, query, changes, callback) ->
		self = @
		# atomize the query
		query = _.rql(query).toMongo()
		query.search.$atomic = 1
		# add history line
		changes ?= {}
		#console.log 'UPDATE?', changes
		history =
			who: changes._meta.modifier
			when: Date.now()
		delete changes._meta
		history.what = changes
		# ensure changes are in multi-update format
		# FIXME: should prohibit $set and id in changes at facet level!!!
		changes = $set: changes #unless changes.$set or changes.$unset
		changes.$push = '_meta.history': history
		# do multi update
		@collections[collection].update query.search, changes, {multi: true}, (err, result) ->
			callback err
			#self.emit 'update',
			#	collection: collection
			#	search: query.search
			#	changes: changes
			#	err: err?.message
			#	result: result

	remove: (collection, query, callback) ->
		self = @
		query = _.rql(query).toMongo()
		# naive fuser
		return callback 'Refuse to remove all documents w/o conditions' unless _.keys(query.search).length
		@collections[collection].remove query.search, (err) ->
			callback err
			#self.emit 'remove',
			#	collection: collection
			#	search: query.search
			#	error: err?.message

time1 = null
time2 = null

db = new Database 'mongodb://127.0.0.1:27017/simple'
Next db,
	(err, result, next) ->
		@open ['Language'], next
	(err, result, next) ->
		@remove 'Language', 'all!=true', next
	(err, result, next) ->
		@add 'Language', {id: 'fr1'}, next
	(err, result, next) ->
		console.log 'ADDED', arguments
		@add 'Language', {foo: 'bar'}, next
	(err, result, next) ->
		@put 'Language', {_id: 'fr2', name: 'Francais'}, next
	(err, result, next) ->
		@get 'Language', 'fr1', next
	(err, result, next) ->
		console.log 'GOT fr1', arguments
		@remove 'Language', ['fr1'], next
	(err, result, next) ->
		@update 'Language', '', {tanya: true}, next
	(err, result, next) ->
		# FIXME: sort!
		#@query 'Language', 'tanya!=false&select(foo)&sort(-id)', next
		@query 'Language', 'tanya!=false&select(foo)', next
	(err, result, next) ->
		console.log 'QUERIED', arguments
		@remove 'Language', 'all!=true', next
	(err, result, next) ->
		time1 = Date.now()
		console.log 'START:'
		nonce = () -> Math.random().toString().substring(2)
		for i in [10000...0]
			do () -> db.add 'Language', {name: nonce()}, (err, result) -> next() unless i
		return
	(err, result, next) ->
		time2 = Date.now()
		# 6000
		# 5500 id <-> _id
		# 5300 emit 'add', ...
		# 4100 _meta
		console.log 'DONE:', "#{10000000/(time2-time1)} doc/sec"
