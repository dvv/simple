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

console.log _.query [{val:2000},{val:1}], '(val%3E1000)'
