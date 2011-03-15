'use static'

Path = require 'path'
Url = require 'url'
Fs = require 'fs'
getMime = require('simple-mime') 'application/octet-stream'

# super simple static file server
#
# thanks creationix/creationix/static
#
module.exports = (mount = '/', root = 'public', index = 'index.html', options = {}) ->

	ENOENT = require('constants').ENOENT
	mlength = mount.length

	handle = (req, res, next) ->

		#
		# determine file path
		#
		path = unescape(req.location.pathname).replace /\.\.+/g, '.'
		return next() if not path or path.substr(0, mlength) isnt mount
		path = Path.join root, path.substr(mlength)
		path = path.substr(0, path.length - 1) if path[path.length - 1] is '/'

		#
		# serve file
		#
		onStat = (err, stat) ->
			if err
				return next() if err.errno is ENOENT
				return next err
			if index and stat.isDirectory()
				path = Path.join path, index
				return Fs.stat path, onStat
			return next(err) unless stat.isFile()
			headers =
				'Date': (new Date()).toUTCString()
				'Last-Modified': stat.mtime.toUTCString()
			if headers['Last-Modified'] is req.headers['if-modified-since']
				return res.send 304, headers
			start = 0
			end = stat.size - 1
			code = 200
			if req.headers.range
				p = req.headers.range.indexOf '='
				parts = req.headers.range.substr(p + 1).split '-'
				if parts[0].length
					start = +parts[0]
					if parts[1].length
						end = +parts[1]
				else
					if parts[1].length
						start = end + 1 - +parts[1]
				if end < start or start < 0 or end >= stat.size
					return res.send 416, headers
				code = 206
				headers['Content-Range'] = "bytes #{start}-#{end}/#{stat.size}"
			headers['Content-Length'] = end - start + 1
			headers['Content-Type'] = getMime path
			if stat.size is 0
				return res.send code, headers
			stream = Fs.createReadStream path, start: start, end: end
			stream.once 'data', (chunk) ->
				res.writeHead code, headers
			stream.pipe res
			stream.on 'error', next

		Fs.stat path, onStat
