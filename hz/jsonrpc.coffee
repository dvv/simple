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
# REST handler
#
# given req.context, try to find there the request handler and execute it
#
module.exports.rest = (options = {}) ->

	(req, res, next) ->

		#console.log 'PARSEDBODY', req.params
		# pass errors to serializer
		return step req.params if typeof req.params is 'string'
		#
		# parse the query
		#
		search = decodeURI(req.location.search or '')
		#console.log 'QUERY?', search
		query = _.rql search
		#console.log 'QUERY!', query
		return step query.error if query.error
		#
		# find the method which will handle the request
		#
		method = req.method
		parts = req.location.pathname.substring(1).split('/').map (x) -> decodeURIComponent x
		data = req.params
		context = req.context
		#
		# translate REST into an RPC call
		#
		if method is 'GET'
			#
			# GET /Foo?query --> RPC {jsonrpc: '2.0', method: ['Foo', 'query'], params: [query]}
			# GET /Foo/ID?query --> RPC {jsonrpc: '2.0', method: ['Foo', 'get'], params: [ID]}
			#
			call =
				jsonrpc: '2.0'
				method: 'query'
				params: [query]
			if parts[1]
				call.method = 'get'
				call.params[0] = parts[1] # ??? [parts[1]]
		else if method is 'PUT'
			#
			# PUT /Foo?query {changes} --> RPC {jsonrpc: '2.0', method: ['Foo', 'update'], params: [query, changes]}
			# PUT /Foo/ID?query {changes} --> RPC {jsonrpc: '2.0', method: ['Foo', 'update'], params: [[ID], changes]}
			# TODO: PUT /Foo/ID?query {ids:[], changes:changes} --> RPC {jsonrpc: '2.0', method: ['Foo', 'update'], params: [[ids], changes]}
			#
			call =
				jsonrpc: '2.0'
				method: 'update'
				params: [query, data]
			if parts[1]
				call.params[0] = [parts[1]]
		else if method is 'POST'
			if data.jsonrpc # and data.method
				call = data
				#
				# POST / {method: M, params: P,...} --> context[M].apply context, P
				# POST /Foo {method: [M, N], params: P,...} --> context.Foo[M][N].apply context, P
				#
				# TODO:
				# update takes _array_ [query, changes]
				# FIXME: params check and recheck and triple check!!!
			else
				#
				# POST /Foo {props} --> context[Foo].add.apply context, props
				#
				call =
					jsonrpc: '2.0'
					method: 'add'
					params: [data]
		else if method is 'DELETE'
			#
			# DELETE /Foo?query -->RPC {jsonrpc: '2.0', method: ['Foo', 'remove'], params: [query]}
			# DELETE /Foo/ID?query --> POST /Foo {method: 'remove', params: [[ID]]}
			# TODO: DELETE /Foo/ID?query {ids:[]} --> POST /Foo {method: 'remove', params: [ids]}
			#
			call =
				jsonrpc: '2.0'
				method: 'remove'
				params: [query]
			if parts[1]
				call.params[0] = [parts[1]]
		else
			# verb not supported
			return next()
		#
		# honor parts[0]
		#
		if parts[0] isnt ''
			call.method = if call.method then [parts[0], call.method] else [parts[0]]
		#
		# populate req.data
		#
		req.data = call
		console.log 'DATA', req.data
		next()

#
# jsonrpc handler
#
# given req.context, try to find there the request handler and execute it
#
# TODO: document!
#
module.exports.jsonrpc = (options = {}) ->

	# TODO: put here a generic json-rpc.handler

	(req, res, next) ->

		#console.log 'HEADS', req.headers
		#return next() unless req.headers.accept.split(';')[0] is 'application/json'

		Next {},
			(xxx, yyy, step) ->
				#console.log 'PARSEDBODY', req.params
				# pass errors to serializer
				return step req.params if typeof req.params is 'string'
				#
				# parse the query
				#
				search = decodeURI(req.location.search or '')
				#console.log 'QUERY?', search
				query = _.rql search
				#console.log 'QUERY!', query
				return step query.error if query.error
				#
				# find the method which will handle the request
				#
				method = req.method
				parts = req.location.pathname.substring(1).split('/').map (x) -> decodeURIComponent x
				data = req.params
				context = req.context
				#
				# translate REST into an RPC call
				#
				# TODO: separate handler!
				#
				if method is 'GET'
					#
					# GET /Foo?query --> POST /Foo {method: 'query', params: [query]}
					# GET /Foo/ID?query --> POST /Foo {method: 'get', params: [ID]}
					#
					call =
						jsonrpc: '2.0'
						method: 'query'
						params: [query]
					if parts[1]
						call.method = 'get'
						call.params = [parts[1]]
				else if method is 'PUT'
					#
					# PUT /Foo?query {changes} --> POST /Foo {method: 'update', params: [query, changes]}
					# TODO: PUT /Foo/ID?query {changes} --> POST /Foo {method: 'update', params: [[ID], changes]}
					# TODO: PUT /Foo/ID?query {ids:[], changes:changes} --> POST /Foo {method: 'update', params: [[ids], changes]}
					#
					call =
						jsonrpc: '2.0'
						method: 'update'
						params: [query, data]
					if parts[1]
						call.params = [[parts[1]], data]
				else if method is 'POST'
					if data.jsonrpc # and data.method
						call = data
						#
						# POST / {method: M, params: P,...} --> context[M].apply context, P
						# POST /Foo {method: [M, N], params: P,...} --> context.Foo[M][N].apply context, P
						#
						# TODO:
						# update takes _array_ [query, changes]
						# FIXME: params check and recheck and triple check!!!
					else
						#
						# POST /Foo {props} --> context[Foo].add.apply context, props
						#
						call =
							jsonrpc: '2.0'
							method: 'add'
							params: [data]
				else if method is 'DELETE'
					#
					# DELETE /Foo?query --> POST /Foo {method: 'remove', params: [query]}
					# TODO: DELETE /Foo/ID?query --> POST /Foo {method: 'remove', params: [[ID]]}
					# TODO: DELETE /Foo/ID?query {ids:[]} --> POST /Foo {method: 'remove', params: [ids]}
					#
					call =
						jsonrpc: '2.0'
						method: 'remove'
						#params: if Array.isArray data?.ids then [data.ids] else [query]
						params: [query]
					if parts[1]
						call.params = [[parts[1]]]
				else
					# verb not supported
					return next()
				#
				# do RPC call
				#
				# descend into context own properties
				#
				#
				if parts[0] isnt ''
					call.method = if call.method then [parts[0], call.method] else [parts[0]]
				#console.log 'CALL', call
				fn = _.get context, call.method
				if fn
					args = if Array.isArray call.params then call.params else if call.params then [call.params] else []
					args.unshift context
					args.push step
					console.log 'CALLING', args, fn.length
					if args.length isnt fn.length
						return step 406
					fn.apply null, args
					#return
				else
					# no handler in context
					# check login call
					if call.method is 'login' and context.verify
						context.verify call.params, (err, session) ->
							step res.setSession err or session
					else
						# no handler here
						#console.log 'NOTFOUND', call
						next()
			(err, result) ->
				#console.log 'RESULT', arguments
				response =
					jsonrpc: '2.0'
				#response.id = data.id if data?.id
				if err
					response.error = err.message or err
				else if result is undefined
					response.result = true
				else
					response.result = result
				# respond
				#res.send response, 'content-type': 'application/json-rpc; charset=utf-8'
				res.send response

