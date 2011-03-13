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
# convert REST to RPC
#

module.exports = (method, uri, query, data) ->

	#
	# split to resource path and resource id
	#
	[parts..., id] = uri.substring(1).split('/').map (x) -> decodeURIComponent x
	if parts.length is 0
		parts = [id]
		id = undefined

	if method is 'GET'
		#
		# GET /Foo[?query] --> RPC {method: ['Foo', 'query'], params: [query]}
		# GET /Foo/ID[?query] --> RPC {method: ['Foo', 'get'], params: [ID]}
		#
		call =
			method: 'query'
			params: [query]
		if id
			call.method = 'get'
			call.params[0] = id
	else if method is 'PUT'
		#
		# PUT /Foo[?query] {changes} --> RPC {method: ['Foo', 'update'], params: [query, changes]}
		# PUT /Foo/ID[?query] {changes} --> RPC {method: ['Foo', 'update'], params: [[ID], changes]}
		# PUT /Foo[/ID][?query] [ids, changes] --> RPC {method: ['Foo', 'update'], params: [ids, changes]}
		#
		call =
			method: 'update'
			params: [query, data]
		if id
			call.params[0] = [id]
		if Array.isArray data
			call.params = data
	else if method is 'POST'
		#
		# POST /Foo {data} --> RPC {method: ['Foo', 'add'], params: [data]}
		#
		call =
			method: 'add'
			params: [data]
	else if method is 'DELETE'
		#
		# DELETE /Foo[?query] --> RPC {method: ['Foo', 'remove'], params: [query]}
		# DELETE /Foo/ID[?query] --> RPC {method: ['Foo', 'remove'], params: [[ID]]}
		# DELETE /Foo[/ID][?query] [ids] --> RPC {method: ['Foo', 'remove'], params: [ids]}
		#
		call =
			method: 'remove'
			params: [query]
		if id
			call.params[0] = [id]
		if Array.isArray data
			call.params = [data]
	else
		#
		# verb not supported
		#
		return

	#
	# honor parts[0:-1]
	#
	if parts[0] isnt ''
		call.method = parts.concat call.method

	#call.jsonrpc = '2.0'
	call

#
# tests
#
assert = require 'assert'
id = 'I-D'
query = 'a=b&select(c)'
tests = [

	#
	# query
	#
	[['GET', '/', '', {}], {method: 'query', params: ['']}]
	[['GET', '/ /  /', '', {}], {method: [' ', '  ', 'query'], params: ['']}]
	[['GET', '/', query, {}], {method: 'query', params: [query]}]
	[['GET', '/ /  /', query, {}], {method: [' ', '  ', 'query'], params: [query]}]
	[['GET', '/Foo', query, {}], {method: ['Foo','query'], params: [query]}]
	[['GET', '/Foo', query, {foo: 123}], {method: ['Foo','query'], params: [query]}]
	[['GET', '/Foo', query, [123]], {method: ['Foo','query'], params: [query]}]

	#
	# get
	#
	[['GET', "/Foo/#{id}", '', {}], {method: ['Foo','get'], params: [id]}]
	[['GET', "/Foo/#{id}", '', ''], {method: ['Foo','get'], params: [id]}]
	[['GET', "/Foo/#{id}", query, undefined], {method: ['Foo','get'], params: [id]}]
	[['GET', "/Foo/a'/#{id}", query, null], {method: ['Foo',"a'",'get'], params: [id]}]

	#
	# remove
	#
	[['DELETE', '/', '', {}], {method: 'remove', params: ['']}]
	[['DELETE', '/ /  /', '', {}], {method: [' ', '  ', 'remove'], params: ['']}]
	[['DELETE', '/Foo', query, {}], {method: ['Foo','remove'], params: [query]}]
	[['DELETE', '/Foo', query, {foo: 123}], {method: ['Foo','remove'], params: [query]}]
	[['DELETE', '/Foo', query, [123,456,null,undefined]], {method: ['Foo','remove'], params: [[123,456,null,undefined]]}]
	[['DELETE', "/Foo/#{id}", '', {}], {method: ['Foo','remove'], params: [[id]]}]
	[['DELETE', "/Foo/#{id}", '', ''], {method: ['Foo','remove'], params: [[id]]}]
	[['DELETE', "/Foo/#{id}", query, undefined], {method: ['Foo','remove'], params: [[id]]}]
	[['DELETE', "/Foo/a'/#{id}", query, null], {method: ['Foo',"a'",'remove'], params: [[id]]}]
	[['DELETE', "/Foo/a'/#{id}", query, ['q','w','e/r/t']], {method: ['Foo',"a'",'remove'], params: [['q','w','e/r/t']]}]

	#
	# update
	#
	[['PUT', '/', '', {}], {method: 'update', params: ['',{}]}]
	[['PUT', '/ /  /', '', {}], {method: [' ', '  ', 'update'], params: ['',{}]}]
	[['PUT', '/Foo', query, {}], {method: ['Foo','update'], params: [query,{}]}]
	[['PUT', '/Foo', query, {foo: 123}], {method: ['Foo','update'], params: [query,{foo: 123}]}]
	[['PUT', '/Foo', query, [123,456,null,undefined]], {method: ['Foo','update'], params: [123,456,null,undefined]}]
	[['PUT', "/Foo/#{id}", '', {}], {method: ['Foo','update'], params: [[id],{}]}]
	[['PUT', "/Foo/#{id}", '', ''], {method: ['Foo','update'], params: [[id],'']}]
	[['PUT', "/Foo/#{id}", query, undefined], {method: ['Foo','update'], params: [[id],undefined]}]
	[['PUT', "/Foo/a'/#{id}", query, null], {method: ['Foo',"a'",'update'], params: [[id],null]}]
	[['PUT', "/Foo/a'/#{id}", query, ['q','w','e/r/t']], {method: ['Foo',"a'",'update'], params: ['q','w','e/r/t']}]

	#
	# add
	#
	[['POST', '/', '', {}], {method: 'add', params: [{}]}]
	[['POST', '/ /  /', '', {}], {method: [' ', '  ', 'add'], params: [{}]}]
	[['POST', '/Foo', query, {}], {method: ['Foo','add'], params: [{}]}]
	[['POST', '/Foo', query, {foo: 123}], {method: ['Foo','add'], params: [{foo: 123}]}]
	[['POST', '/Foo', query, [123,456,null,undefined]], {method: ['Foo','add'], params: [[123,456,null,undefined]]}]
	[['POST', "/Foo/#{id}", '', {}], {method: ['Foo','add'], params: [{}]}]
	[['POST', "/Foo/#{id}", '', ''], {method: ['Foo','add'], params: ['']}]
	[['POST', "/Foo/#{id}", query, undefined], {method: ['Foo','add'], params: [undefined]}]
	[['POST', "/Foo/a'/#{id}", query, null], {method: ['Foo',"a'",'add'], params: [null]}]
	[['POST', "/Foo/a'/#{id}", query, ['q','w','e/r/t']], {method: ['Foo',"a'",'add'], params: [['q','w','e/r/t']]}]

]
tests.forEach (test) ->
	assert.deepEqual module.exports.apply(null, test[0]), test[1] #, test[0]
