'use strict'

###
 *
 * Simple
 * Copyright(c) 2011 Vladimir Dronnikov <dronnikov@gmail.com>
 * MIT Licensed
 *
###

http = require 'http'
parseUrl = require('url').parse

htmlparser = require 'htmlparser'

parseText = (data, next) ->
	handler = new htmlparser.DefaultHandler (err, dom) ->
		next err, dom
	,
		ignoreWhitespace: true
		verbose: false
	parser = new htmlparser.Parser handler
	parser.parseComplete data

parseLocation = (url, next) ->
	req = parseUrl url
	req =
		host: req.hostname
		port: req.port or {http: 80, https: 443}[req.protocol] or 3128
		path: req.pathname + (if req.search then req.search else '')
		headers:
			accept: '*/*'
			'user-agent': 'wget 1.14'
	if proxy = process.env["#{req.protocol}_proxy"] or process.env.http_proxy
		proxy = parseUrl proxy
		req.headers.host = req.host
		req.port = proxy.port or 80
		req.host = proxy.hostname
		req.path = url
	handler = new htmlparser.DefaultHandler (err, dom) ->
		next err, dom
	,
		ignoreWhitespace: true
		verbose: false
	parser = new htmlparser.Parser handler
	wget = http.get req, (res) ->
		if res.statusCode > 299
			return next res.statusCode
		res.on 'data', (data) -> parser.parseChunk data
		res.on 'end', -> parser.done()
		res.on 'error', (err) -> parser.done()

module.exports =
	parseText: parseText
	parseLocation: parseLocation
