#!/usr/local/bin/coffee
'use strict'

global._ = require './node_modules/underscore'
require './src/object'
parseHTML = require('./src/remote').parseLocation
require './src/rql'

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 10

###
fetchCourses = (referenceCurrency = 'usd', next) ->
	parseHTML "http://xurrency.com/#{referenceCurrency.toLowerCase()}/feed", (err, dom) ->
		course = _.map dom[1].children, (rec) ->
			cur: rec.children[9]?.children[0].data
			val: +rec.children[10]?.children[0].data
			date: Date rec.children[4]?.children[0].data
		course[0].cur = referenceCurrency.toLowerCase()
		course[0].val = 1
		next err, course

fetchCourses 'usd', console.log
###

console.log _.query [{val:2000},{val:1}], '(val%3E1000)'
