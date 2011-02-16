#!/usr/local/bin/coffee
'use strict'

process.argv.shift() # still report 'node' as argv[0]

simple = require './src'

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 10

#
# configuration
#
config =

	server:

		port: 3000
		workers: require('os').cpus().length
		#uid: 65534
		#gid: 65534
		#pwd: './secured-root'
		#sslKey: 'key.pem'
		#sslCert: 'cert.pem'
		repl: true
		pub:
			dir: 'test'
			ttl: 3600
		stackTrace: true

	security:

		#bypass: true
		secret: 'change-me-on-production-server'
		roots:
			root:
				id: 'root'
				email: 'place-admin@here.com'
				password: '123'
				secret: '321'
				type: 'root'

	database:

		url: '' #'mongodb://127.0.0.1/simple'
		#attrInactive: '_deleted'

#
# DB model definitions
#
schema = {}

schema.Language =
	type: 'object'
	additionalProperties: false # seal the schema -- allow only explicitly defined properties
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
			veto:
				update: true # prohibit this property in 'update' operation
		name:
			type: 'string'
		localName:
			type: 'string'

schema.Geo =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
			pattern: /^[A-Z]{2}$/
		name:
			type: 'string'
		iso3:
			type: 'string'
			pattern: /^[A-Z]{3}$/
		code:
			type: 'string'
			pattern: /^[0-9]{3}$/
		cont:
			type: 'string'
			default: 'SA'
			pattern: /^[A-Z]{2}$/
		tz:
			type: 'array'
			optional: true
			items:
				type: 'string'
				pattern: /^UTC/

schema.Course =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
		cur:
			type: 'string'
			pattern: /^[A-Z]{3}$/
		name:
			type: 'string'
		value:
			type: 'number'
		date:
			type: 'date'

#
# ...
#

RestrictiveFacet = (obj, plus...) ->
	# register permissive facet -- set of entity getters
	expose = ['schema', 'id', 'query', 'get']
	expose = expose.concat plus if plus.length
	_.proxy obj, expose

PermissiveFacet = (obj, plus...) ->
	# register permissive facet -- set of entity accessors
	expose = ['schema', 'id', 'query', 'get', 'add', 'update', 'remove', 'delete', 'undelete', 'purge']
	expose = expose.concat plus if plus.length
	_.proxy obj, expose

parseLocation = require('./src/remote').parseLocation
fetchCourses = (referenceCurrency = 'usd', query, next) ->
	parseLocation "http://xurrency.com/#{referenceCurrency.toLowerCase()}/feed", (err, dom) ->
		course = _.map dom[1].children, (rec) ->
			cur: rec.children[9]?.children[0].data
			value: +rec.children[10]?.children[0].data
			date: Date rec.children[4]?.children[0].data
		course[0].cur = referenceCurrency.toUpperCase()
		course[0].value = 1
		course = _.toHash course, 'cur'
		parseLocation 'http://xurrency.com/currencies', (err, dom) ->
			currs = dom[1].children[1].children[0].children[1].children[0].children[4].children.slice(1)
			_.each currs, (rec) ->
				x = rec.children[1].children[0]
				course[x.attribs.href.substring(1).toUpperCase()]?.name = x.children[0].data
			#console.log course
			#process.exit 0
			course = _.toArray course
			next null, course

fetchGeo = (next) ->
	geo = {}
	geoByName = {}
	parseLocation 'http://en.wikipedia.org/wiki/ISO_3166-1', (err, data) ->
		fn = (node) ->
			if node.name is 'table' and node.attribs?.class is 'wikitable sortable'
				#console.log 'NODE?'
				node.children.slice(1).forEach (tr) ->
					#console.log tr.children[0].children[1]
					id = tr.children[1].children[0].children[0].children[0].data
					geo[id] =
						id: id
						name: decodeURI(tr.children[0].children[1].attribs?.title or tr.children[0].children[1].children[1].attribs?.title)
						#wiki: tr.children[0].children[1].attribs?.href or tr.children[0].children[1].children[1].attribs?.href
						iso3: tr.children[2].children[0].children[0].data
						code: tr.children[3].children[0].children[0].data
					geoByName[geo[id].name] = id
			else if node.children
				node.children.forEach fn
		data.forEach fn
		parseLocation 'http://en.wikipedia.org/wiki/List_of_countries_by_continent_(data_file)', (err, data) ->
			fn = (node) ->
				if node.name is 'pre'
					node.children[0].data.split('\n').forEach (x) ->
						[cont, id] = x.split(' ').slice(0, 2)
						if id and geo[id]
							geo[id].cont = cont
						else if id
							console.error 'NO COUNTRY', id, cont
				else if node.children
					node.children.forEach fn
			data.forEach fn
			parseLocation 'http://en.wikipedia.org/wiki/List_of_time_zones_by_country', (err, data) ->
				#console.log data
				fn = (node) ->
					if node.name is 'table' and node.attribs?.class is 'wikitable sortable'
						#console.log 'NODE?'
						node.children.slice(1).forEach (tr) ->
							#console.log tr.children[2].children
							name = tr.children[0].children[1].attribs.title
							#############
							# FIXME: two kingdoms
							#
							if name.substring(0,11).toLowerCase() is 'kingdom of '
								name = name.split(' ').slice(-1)
							#
							#############
							id = geoByName[name]
							if not geo[id]
								console.error 'TZ FOR NO COUNTRY', name
								return
							geo[id].tz = []
							tr.children[2].children.forEach (x) ->
								if x.name is 'a' and x.attribs.title.substring(0,3) is 'UTC'
									geo[id].tz.push x.attribs.title
					else if node.children
						node.children.forEach fn
				data.forEach fn
				geo = _.toArray geo
				next null, geo

#
# setup and run the server
#
All {},

	#
	# define DB model
	#
	(err, result, next) ->

		new simple.Database config.database.url, schema, next

	#
	# define application
	#
	(err, exposed, next) ->

		model = exposed

		facet =
			Language: PermissiveFacet model.Language
			Geo: RestrictiveFacet model.Geo
			Course: RestrictiveFacet model.Course

		#
		# fill the DB
		#
		ctx = {user: {id:'root'}}
		fetchCourses null, null, (err, result) ->
			global.course = result.slice()
			if not process.env._WID_
				model.Course.remove ctx, 'a!=b', () ->
				_.each result, (rec) ->
					model.Course.add ctx, rec, (err, result) ->
						console.log 'COURSEFAILED', rec.name if err
		###
		fetchGeo (err, result) ->
			global.geo = result.slice()
			if not process.env._WID_
				model.Geo.remove ctx, 'a!=b', () ->
					_.each result, (rec) ->
						model.Geo.add ctx, rec, (err, result) ->
							console.log 'GEOFAILED', rec.name if err
		###

		#
		# app should provide for .getContext(uid, next) -- the method to retrieve
		#   capability object for given user uid
		#
		app = Object.freeze
			getContext: (uid, next) ->
				context = _.extend.apply null, [{}, facet]
				next? null, _.freeze context
		next null, app

	#
	# define server
	#
	(err, app, next) ->

		#
		# define middleware stack
		#
		handler = simple.stack(

			simple.handlers.jsonBody
				maxLength: 0 # set to >0 to limit the number of bytes

			#simple.handlers.mount '/foo1',
			#	get: (req, res, next) -> res.send 'GETFOO1'
			#	post: (req, res, next) -> res.send 'POSTFOO1'

			simple.handlers.authCookie
				cookie: 'uid'
				secret: config.security.secret
				getContext: app.getContext

			simple.handlers.mount 'GET', '/home', (req, res, next) ->
				res.send 'GOT FROM HOME'

			simple.handlers.mount 'GET', '/course', (req, res, next) ->
				#console.log req.location.search
				query = _.rql decodeURI(req.location.search or '')
				res.send _.query(course, query)

			simple.handlers.mount 'GET', '/geo', (req, res, next) ->
				#console.log req.location.search
				query = _.rql decodeURI(req.location.search or '')
				res.send _.query(geo, query)

			#simple.handlers.logRequest()

			simple.handlers.jsonrpc()

			simple.handlers.mount 'POST', '/foo', (req, res, next) ->
				res.send 'POSTED TO FOO'

			simple.handlers.static_
				dir: config.server.pub.dir
				ttl: config.server.pub.ttl

		)

		#
		# run the application
		#
		simple.run handler, config.server

	#
	# define fallback
	#
	(err, result, next) ->

		console.log "OOPS, shouldn't have been here!", err
