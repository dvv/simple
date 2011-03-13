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
# improve http.IncomingMessage
#
require './request'

#
# improve http.ServerResponse
#
require './response'

#
# thanks creationix/Stack
#
Stack = (layers...) ->
	handle = errorHandler
	layers.reverse().forEach (layer) ->
		child = handle
		handle = (req, res) ->
			try
				layer req, res, (err) ->
					return errorHandler req, res, err if err
					child req, res
			catch err
				errorHandler req, res, err
	handle

#
# mixin handlers
#
Stack[name] = fn for own name, fn of require('./handlers')

#
# fallback and error handler
#
errorHandler = (req, res, err) ->
	if err
		# TODO: configurable
		console.error err.stack or err.message
		res.send err
		return
	res.send 404

module.exports = Stack
