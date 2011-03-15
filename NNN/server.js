//
// console.log helper
//
var sys = require('util');
console.log = function(){
	for (var i = 0, l = arguments.lenght; i < l; ++i) {
		console.error(sys.inspect(arguments[i], false, 10));
	}
};

//
// flow helpers: Next, All
//
require('./lib/flow');

//
// create a server
//
var express = require('express');
var app = express.createServer(/*{key: ...}*/);

//
// define capabilities
//
function getCapability(uid, callback){
	var context = {
		user: {}
	};
	callback(null, context);
}

//
// MIDDLEWARE
//
// cache req.context with capability of current session user
//
// use after cookie-sessions
//
function capability(getCapability){
	var cache = {}; // contexts cache
	return function capability(req, res, next){
		//
		// fill context
		//
		// N.B. map all falsy users to uid=''
		var uid = req.session && req.session.uid || '';
		// cached context?
		if (cache.hasOwnProperty(uid)) {
			req.context = cache[uid];
			next();
		// get and cache context
		} else {
			getCapability(uid, function(err, context){
				// N.B. don't cache negatives
				if (context) {
					cache[uid] = req.context = context;
				}
				next(err);
			});
		}
	};
}

//
// MIDDLEWARE
//
// convert REST to RPC
//
// depends on req.body
//
function rest2rpc(){
	var convertToRPC = require('./lib/rest');
	var parseURL = require('url').parse;
	return function rest2rpc(req, res, next){
		//
		// URL and method define RPC method
		//
		location = parseURL(req.url, false);
		var data = req.body || {};
		var query = decodeURI(location.search || '');
		//
		// if body doesn't look like RPC -- convert REST to JSONRPC
		//
		if (!(data.jsonrpc && data.hasOwnProperty('method') && data.hasOwnProperty('params'))) {
			data = convertToRPC(req.method, location.pathname, query, data);
			data.jsonrpc = '2.0';
		}
		//
		req.jsonrpc = data;
		next();
	};
}

//
// MIDDLEWARE
//
// call a method of req.context
//
// depends on req.jsonrpc
//
function jsonrpc(){
	return function jsonrpc(req, res, next){
		//
		// find RPC handler
		//
		var fn = req.context;
		var method = req.jsonrpc.method;
		var params = req.jsonrpc.params;
		// method is an array ->
		if (Array.isArray(method)) {
			// each element defines a drill-down step
			for (var i = 0, l = method.length; i < l; ++i) {
				fn = fn && fn[method[i]];
			}
		// method is ordinal ->
		} else {
			// simple lookup
			fn = fn && fn[method];
		}
		//
		// call RPC handler
		//
		if (fn) {
			Next(req.context,
				// safely call the handler
				function(err, result, step){
					// compose arguments from data.params
					var args = Array.isArray(params) ? params.slice() : params ? [params] : [];
					// the first argument is the context
					args.unshift(req.context);
					// the last argument is the next step
					args.push(step);
					// check if handler arity equals arguments length
					if (args.length !== fn.length) {
						return step(SyntaxError('Invalid method signature'));
					}
					// provide null as `this` to not leak info
					fn.apply(null, args);
				},
				// respond with JSONRPC answer
				function(err, result){
					var response;
					if (req.jsonrpc.jsonrpc) {
						response = {
							jsonrpc: req.jsonrpc.jsonrpc
						};
						if (err) {
							response.error = err.message || err;
						} else if (result === void 0) {
							response.result = true;
						} else {
							response.result = result;
						}
					} else {
						response = err || result;
					}
					res.send(response);
				}
			);
		//
		// no handler found
		//
		} else {
			next();
		}
	};
}

app.configure(function(){

	app.use(express.logger());

	app.use(require('cookie-sessions')({
		secret: 'your secret here',
		session_key: 'sid',
		//timeout: 24*60*60*1000
	}));

	app.use(capability(getCapability));

	app.use(express.bodyParser());
	/*
	app.use(require('connect-form')({
		uploadDir: __dirname + '/upload',
		keepExtensions: true
	}));
	app.use(function(req, res, next){
		if (req.form) {
			// Do something when parsing is finished
			// and respond, or respond immediately
			// and work with the files.
			req.form.onComplete = function(err, fields, files){
				res.writeHead(200, {});
				if (err) res.write(JSON.stringify(err.message));
				res.write(JSON.stringify(fields));
				res.write(JSON.stringify(files));
				res.end();
			};
			// Regular request, pass to next middleware
		} else {
			next();
		}
	});
	*/

	//app.use(require('connect-auth')(MyAuthStrategy()));

	app.use(rest2rpc());
	app.use(jsonrpc());

	app.use(function(req, res, next){
		console.log('BODY', req.body);
		console.log('SESSION', req.session);
		console.log('CONTEXT', req.context);
		next();
	});

	app.use(function(req, res, next){
		if (req.jsonrpc.method === 'login') {
/*
		login: function(ctx, credentials, callback){
			// TODO: check creds -- reuse handler from basicAuth?
			//credentials.id, credentials.password
			if (ctx.user.id) {
			} else {
			}
			//req.session = {uid: credentials.id};
			callback();
		}
 */

			req.session = {uid: 'fooo'};
			console.log('SSSS');
			return res.send(444);
		}
		next();
	});

	//app.use(require('connect-jsonrpc')(math, date, hz));

	app.use(express.static(__dirname + '/public'));
});

app.get('/admin', function(req, res, next){
	req.authenticate(['someName'], function(err, user){
		res.send('Penetrated!');
	});
});

app.get('/', function(req, res, next){
	res.send('HELLO WORLD!');
});

//app.listen(3000);

if (true) {
	var worker = require('stereo')(app, {
		port: 3000,
		repl: true,
		workers: 1,
		watch: [__filename]
	});
	if (worker) { // worker process
		// inter-workers message arrives
		process.on('message', function(message){
			console.log(JSON.stringify(message));
		});
	} else { // master process
		// broadcast a message
		setTimeout(function(){process.publish({sos: 'to all, all, all'});}, 2000);
	}
} else {
	var cluster = require('cluster');
	cluster(app)
		.set('workers', 2)
		.use(cluster.debug())
		.use(cluster.stats())
		.use(cluster.reload())
		.use(cluster.repl(30000))
		.listen(3000);
}
