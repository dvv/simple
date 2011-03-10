'use strict'

###

     Vladimir Dronnikov 2011 dronnikov@gmail.com

     Redistribution and use in source and binary forms, with or without
     modification, are permitted provided that the following conditions are
     met:

     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above
       copyright notice, this list of conditions and the following disclaimer
       in the documentation and/or other materials provided with the
       distribution.
     * Neither the name of the  nor the names of its
       contributors may be used to endorse or promote products derived from
       this software without specific prior written permission.

     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
     A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
     OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
     SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
     LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
     DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
     THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
     (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
     OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

###

#
# improve console.log
#
sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 10
	return

#
# flow
#
global.Next = (context, steps...) ->
	next = (err, result) ->
		# N.B. only simple steps are supported -- no next.group() and next.parallel() as in Step
		fn = steps.shift()
		if fn
			try
				fn.call context, err, result, next
			catch err
				next err
		else
			throw err if err
		return
	next()
Object.defineProperty Next, 'nop', value: () ->

global.All = (context, steps...) ->
	next = (err, result) ->
		throw err if err
		# N.B. only simple steps are supported -- no next.group() and next.parallel() as in Step
		fn = steps.shift()
		if fn
			try
				fn.call context, err, result, next
			catch err
				console.log 'FATAL: ' + err.stack
				process.exit 1
		else
			if err
				console.log 'FATAL: ' + err.stack
				process.exit 1
		return
	next()

#
# expose Object helpers
#
global._ = require 'underscore'
require './object'
require './validate'
require './rql'
Object.freeze _

#
# facet helpers
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


#
# improve http.IncomingMessage
#
require './request'

#
# improve http.ServerResponse
#
require './response'

#
# expose interface
#
module.exports =
	Database: require './database'
	RestrictiveFacet: RestrictiveFacet
	PermissiveFacet: PermissiveFacet
	run: require './server'
	stack: require 'stack'
	handlers: require './handlers'
