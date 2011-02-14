#!/usr/local/bin/coffee
'use strict'

global._ = require './node_modules/underscore'
require './src/U.obj'
require './src/rql'

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 10

obj = [{a:2,b:2,c:1,foo:{bar:'baz1',baz:'raz'}},{a:1,b:4,c:1,foo:{bar:'baz2'}},{a:3,b:0,c:1,foo:{bar:'baz3'}}]

#console.log _.query 'a=2,b<4,pick(-b,a)' #, {}, [{a:2,b:2},{a:2,b:4}]
#console.log _.query 'or((pick(-b,a)&values(a/b/c)))' #, {}, [{a:2,b:2},{a:2,b:4}]
#console.log _.query 'a=2,b<4', {}, [{a:2,b:2},{a:2,b:4}]
#console.log _.query 'a=2,and(b<4)', {}, [{a:2,b:2},{a:2,b:4}]
#console.log _.query 'a>1,b<4,pick(b,foo/bar,-foo/baz,+fo.ba),limit(1,1)', {}, obj
#console.log _.query 'or(eq(a=2),eq(b,4)),pick(b)', {}, obj
#console.log _.query 'and(and(and(hasOwnProperty!=%22123)))', {}, obj
#console.log _.query '', {}, obj
#console.log _.query 'sort(c,foo/bar,foo/baz)', {}, obj
#console.log _.query 'match(foo/bar,z3)', {}, obj
#console.log _.query 'foo/bar!=re:z3', {}, obj
#console.log _.query 'in(foo/bar,(baz1))', {}, obj
#console.log _.query 'between(foo/bar,baz1,baz3)', {}, obj

#x = _.drill obj[0], ['foo', 'bar'], true
#console.log x

#console.log _(obj).chain().and(((x) -> x.a is 2), ((x) -> x.b < 3)).tap(this.pick('b', 'a')).values().value()
#console.log _(obj).chain().and(((x) -> x.a is 2), ((x) -> x.b < 3)).tap((x) -> _.pick(x,'b','a')).values().value()
#console.log _(obj).chain().and(((x) -> x.a is 2), ((x) -> x.b < 3), (x) -> _.pick(x,'b','a')).value()

#console.log _(obj).chain().and(((x) -> x.a is 2), ((x) -> x.b < 3), (x) -> _.pick(x,'b','a')).value()

###
#.and(.or(.and(.pick("-b","a"),.values(["a","b","c"]))))
.and(
	.or(
		.and(
			.pick("-b","a"),.values(["a","b","c"])
		)
	)
)
###

###
_.and(

	_.or(
		_(???).pick(obj,'-b','a').values(['a','b','c']).value()
		_(???).pick(obj,'b','-a').values(['a','b','c']).value()
	)

)

(x) -> _.and(x, _.pick(x

###

#console.log _.pick(_.select(obj, (x) -> x.a is 2 and x.b < 4), 'a')
###
console.log _(obj).or(
	(x) -> _.pick x, 'a', 'b'
	(x) -> _.pick x, '-b', 'a'
	(x) -> _.pick x, 'b', '-a'
	(x) -> _.pick x, 'b', 'a'
	(x) -> _.select x, (y) -> y.a is 2
)
###

###
(a=b&c<d).select(a,b).limit(c,d)

((a,b,eq),(c,d,le),and)

and(eq(a,b),le(c,d),select(-v))

###

###
always return array -- so chaining
and
	a is 2
	and
		b < 4
		pick
			b,a
###

#aaa = (x) -> _.map x, _.values

#console.log aaa [1, 2, 3]
#console.log _.toHash [{a:1}, {a:2}, {a:3}], 'a'
#console.log aaa [1, false, {a:1}, {foo:{bar:'baz'}}]

#console.log _.rql 'match(name,glob:f*)'

console.log '[' + decodeURIComponent(4) + ']'
