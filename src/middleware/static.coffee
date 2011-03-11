###
taken from dvv/stack.static
###

Util   = require 'util'
Path   = require 'path'
Fs     = require 'fs'
Crypto = require 'crypto'
Mime   = require('simple-mime') 'application/octet-stream'

methods = ['GET', 'HEAD']

#
# cache for file stat and file read results
#
cacheInvalid = false
stats = {}
cache = {}

# Public: Sets up a Stack handler for serving static files.
#
# root    - String path to the root directory to serve static files from.
# options - Optional Hash of options:
#           default - String that specifies the default filename for a 
#                     directory.
#           headers - Hash of default headers
#
# Returns a Stack handler function.
exports = module.exports = (root, options = {}) ->
  root        = Path.normalize root
  defaultFile = options.default
  options.etag = exports.etag unless options.etag?

  headers = {}
  options.headers ?= {}
  for key, value of exports.defaultHeaders
    headers[key] = value
  if options.headers
    for key, value of options.headers
      headers[key] = value

  #
  # cache invalidator
  # FIXME: doesn't work...
  #
  #setInterval (-> cacheInvalid = true), options.cacheTTL if options.cacheTTL

  (req, res, next) ->
    if req.url.match /\.\.\//
      return next()
    if methods.indexOf(req.method) == -1
      res.writeHead 405, accept: 'GET, HEAD'
      return res.end()
    if defaultFile and req.url.match(/\/$/)
      req.url = "#{req.url}#{defaultFile}"

    options.headers = headers
    options.file    = "#{root}#{req.url}"
    ## invalidate cache
    #if cacheInvalid
    #  cache = stats = {}
    #  cacheInvalid = false
    exports.serve req, res, options, (err) ->
      next() if err # pass on the request if it's a 404

exports.defaultHeaders = {}

# Public: Serves a given file from the file system.
#
# req     - The http.ServerRequest instance.
# res     - The http.ServerResponse instance.
# options - Hash with the parameters defining the file to serve.
#           file - String path to the file on the file system.
#           etag - Optional Function for generating an Etag.  See writeHead()
# next    - An optional Function callback to be called when the file has 
#           finished streaming.  If the file doesn't exist, an err argument
#           from fs.stat() is passed.
#
# Returns nothing.
exports.serve = (req, res, options = {}, next) ->
  file = options.file
  #process.log 'SERVE', file, stats
  if stats.hasOwnProperty file
    stat = stats[file]
    if stat instanceof Error
      next stat
    else if cache.hasOwnProperty file
      cached = cache[file]
      #data = options.postprocess cached, file if options.postprocess
      exports.writeHead req, res, file, stat, options, (status, fs_options) ->
        if (199 < status < 299) and req.method is 'GET'
          if stat.size > options.cacheMaxFileSizeToCache
            #process.log "PUMP #{file}"
            Util.pump Fs.createReadStream(file, fs_options), res, next
          else
            #process.log "CACHED #{file} RANGE #{fs_options.start}-#{fs_options.end}"
            res.end(if fs_options.start? or fs_options.end? then cached.slice(fs_options.start, fs_options.end) else cached)
            ## invalidate cache
            #if cacheInvalid
            #  cache = stats = {}
            #  cacheInvalid = false
        else
          res.end()
        return
    else
      Fs.readFile file, (err, data) ->
        #process.log "READ #{file}"
        if err
          next err
        else
          #data = options.preprocess data, file if options.preprocess
          cache[file] = data
          exports.serve req, res, options, next
        return
  else
    Fs.stat file, (err, result) ->
      #process.log "STAT #{file}", arguments
      stats[file] = err or result
      if err
        next err
      else
        exports.serve req, res, options, next
      return
  return

# Public: Writes the headers for the HTTP response for the given served file.
#
# res     - The http.ServerResponse instance.
# req     - The http.ServerRequest instance.
# file    - String path to the file on the file system.
# stats   - fs.Stats instance of the file.
# options - Options Hash:
#           status - The default Integer HTTP status code.
#           etag   - A function for generating an ETag, or 'true' to use the
#                    default ETag generator.  If an ETag is generated, it is
#                    checked against an 'if-none-match' request header.
#
# Returns a Hash of headers.
exports.writeHead = (req, res, file, stats, options = {}, cb) ->
  fs_options = {}
  headers    = exports.buildHeaders options.headers, file, stats
  status     = options.status or 200
  ifmod      = req.headers['if-modified-since']

  if ifmod
    since = Date.parse ifmod
    if since and since > stats.mtime.getTime()
      return not_modified res, headers, cb

  ifunmod = req.headers['if-unmodified-since']
  if ifunmod
    since = Date.parse ifunmod
    if since and since < stats.mtime.getTime()
      headers['content-length'] = 0
      res.writeHead 412, headers
      return cb 412

  headers.etag = build_etag file, stats
  if etag_matches req.headers['if-none-match'], headers.etag
    return not_modified res, headers, cb

  range = parse_range stats, req.headers.range
  if range
    status = 206
    headers['content-length'] = range.length
    headers['content-range']  = "bytes #{range.start}-#{range.end}/#{stats.size}"
    fs_options.start = range.start
    fs_options.end   = range.end

  res.writeHead status, headers
  cb status, fs_options

# Public: Sets up the headers for the HTTP response for the given served file.
#
# headers - Hash of default headers on all requests.
# file    - String path to the file on the file system.
# stats   - fs.Stats instance of the file.
#
# Returns a Hash of headers.
exports.buildHeaders = (headers, file, stats) ->
  headers['content-type']   = Mime file
  headers['content-length'] = stats.size
  headers['last-modified']  = stats.mtime.toUTCString()
  headers

# Generates an ETag of the given file by creating a SHA1 hash from the File 
# path + size + mtime.
#
# file  - String path to the file on the file system.
# stats - fs.Stats instance of the file.
#
# Returns the String ETag.
build_etag = (file, stats) ->
  hash = Crypto.createHash 'sha1'
  hash.update file
  hash.update stats.size
  hash.update stats.mtime
  "\"#{hash.digest('hex')}\""

# Parses a HTTP Range header:
#   bytes=0-499 (first 500 bytes)
#   bytes=500- (everything but the first 500 bytes)
#   bytes=-500 (the final 500 bytes)
#
# stats  - fs.Stats instance of the file.
# header - The String value of the Range header.
#
# Returns a Range object with start/end/length properties.
parse_range = (stats, header) ->
  return if !header
  match = header.match /^(bytes=)?(\d*)-(\d*)$/
  return if !match
  range = {}
  range.start  = parseInt match[2] if match[2]
  range.end    = if match[3] then parseInt match[3] else stats.size
  if !range.start
    range.start = stats.size - range.end
    range.end   = stats.size
  range.length = range.end - range.start + 1
  return null if range.start > range.end # N.B. RFC2616: invalid range means no range
  range

# Helper function to write a "304 Not Modified" HTTP response.
#
# res     - The http.ServerResponse instance.
# headers - Hash of HTTP headers.
# cb      - The function callback to be called with the HTTP status code (304).
#
# Returns nothing.
not_modified = (res, headers, cb) ->
  headers['content-length'] = 0
  res.writeHead 304, headers
  cb(304)

# Checks if the requested file's etag matches the requested ETag.
#
# request_etag - String ETag sent in the If-None-Match HTTP request header.
# file_etag    - String ETag of the requested file.
#
# Returns true if the etags match, or false.
etag_matches = (request_etag, file_etag) ->
  request_etag? and file_etag? and request_etag == file_etag
