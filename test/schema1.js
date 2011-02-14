$(document).ready(function(){

	var schema, obj;

	module("Validate: additionalProperties=true");

	schema = {
		type: 'object',
		properties: {
			id: {
				type: 'string',
				pattern: /^[abc]+$/,
				veto: {
					update: true
				}
			},
			foo: {
				type: 'integer',
				veto: {
					get: true
				}
			},
			bar: {
				type: 'array',
				items: {
					type: 'string',
					enum: ['eniki', 'beniki', 'eli', 'vareniki']
				}
			},
			defaulty: {
				type: 'date',
				'default': '2011-02-14'
			}
		},
		additionalProperties: true
	};

	test("add", function(){
		obj = {id: 'bac', foo: '4', bar: 'vareniki', spam: true};
		equals(_.validate(obj, schema, {veto: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'add', coerce: true}),
			null, 'coerced and added ok');
		deepEqual(obj, {id: 'bac', foo: 4, bar: ['vareniki'], defaulty: new Date('2011-02-14'), spam: true}, 'coerced for "add" ok');
		obj = {id: 'bac1', foo: 'a', bar: 'pelmeshki'};
		deepEqual(_.validate(obj, schema, {veto: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'add', coerce: true}),
			[{property: 'id', message: 'pattern'}, {'property': 'foo', 'message': 'type'}, {'property': 'bar[0]', 'message': 'enum'}], 'validate for "add"');
	});

	test("update", function(){
		obj = {id: 'bac', foo1: '5', bar: ['eli', 'eniki']};
		deepEqual(_.validate(obj, schema, {veto: true, removeAdditionalProps: !schema.additionalProperties, existingOnly: true, flavor: 'update', coerce: true}),
			null, 'validate for "update" nak: required');
		deepEqual(obj, {bar: ['eli', 'eniki'], foo1: '5'}, 'validate for "update" ok');
		obj = {id: 'bac', foo: '5', bar: ['eli', 'eniki']};
		deepEqual(_.validate(obj, schema, {veto: true, removeAdditionalProps: !schema.additionalProperties, existingOnly: true, flavor: 'update', coerce: true}),
			null, 'validate for "update" ok');
		deepEqual(obj, {foo: 5, bar: ['eli', 'eniki']}, 'validate for "update" ok');
	});

	test("get", function(){
		obj = {id: 'bac', foo: '5', bar: ['eli', 'eniki'], secret: true};
		deepEqual(_.validate(obj, schema, {veto: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'}),
			null, 'validate for "get" ok');
		deepEqual(obj, {id: 'bac', bar: ['eli', 'eniki'], secret: true}, 'validate for "get" ok');
	});

});
