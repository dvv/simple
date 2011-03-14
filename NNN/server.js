var express = require('express');
var app = express.createServer();

  var math = {
      add: function(a, b, fn){
          fn(null, a + b);
      },
      sub: function(a, b, fn){
          fn(null, a - b);
      }
  };

  var date = {
      time: function(fn){
          fn(null, new Date().toUTCString());
      }
  };

var hz = {
	login: function(user, pass, fn){
		fn(null, 123);
	}
};

function MyAuthStrategy(options){
	options = options || {};
	var that = {};
	var my = {}; 
	that.name = options.name || 'someName';
	that.authenticate = function(req, res, next){
		this.success({uid: '1', name: 'someUser'}, next);
	}
	return that;
};

function getContext(){
	var cache = {};
	return function getContext(req, res, next){
		req.context = {
			user: {}
		};
		var uid = req.session && req.session.uid;
		if (uid) {
			if (cache.hasOwnProperty(uid)) {
				req.context = cache[uid];
			} else {
				req.context = cache[uid] = {
					user: {
						uid: uid
					}
				};
			}
		}
		next();
	};
}

app.configure(function(){
	//app.use(express.logger());

	//app.use(express.cookieParser());
	//app.use(express.session({secret: 'your secret here'}));//, key: 'sid'

	app.use(require('cookie-sessions')({
		secret: 'your secret here',
		session_key: 'sid',
		//timeout: 24*60*60*1000
	}));
	app.use(getContext());

	//app.use(require('connect-auth')(MyAuthStrategy()));

	app.use(express.static(__dirname + '/public'));
	//app.use(express.bodyParser());

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

	app.use(function(req, res, next){
		console.log('PARAMS', req.body);
		console.log('CONTEXT', req.context);
		next();
	});

	//app.use(require('connect-jsonrpc')(math, date, hz));

});

app.get('/admin', function(req, res, next){
	req.authenticate(['someName'], function(err, user){
		res.send('Penetrated!');
	});
});

app.get('/', function(req, res, next){
	//console.log('COOKIE', JSON.stringify(req.cookies));
	//console.log('SESSION', JSON.stringify(req.session));
	res.send('HELLO WORLD!');
});

app.post('/login', function(req, res, next){
	req.session = {uid: 'yes'};
	res.send('?');
});

if (false) {
	app.listen(3000);
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
