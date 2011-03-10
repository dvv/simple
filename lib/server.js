'use strict';
/*

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

*/var framing;
var __slice = Array.prototype.slice, __hasProp = Object.prototype.hasOwnProperty;
framing = function(chunk) {
  var braces, buf, c, i, obj, _len, _results;
  buf = buf || '';
  braces = braces || 0;
  _results = [];
  for (i = 0, _len = chunk.length; i < _len; i++) {
    c = chunk[i];
    if ('{' === c) {
      ++braces;
    }
    if ('}' === c) {
      --braces;
    }
    buf += c;
    _results.push(0 === braces ? (obj = JSON.parse(buf), buf = '', this.emit('message', obj)) : void 0);
  }
  return _results;
};
module.exports = function(app, options) {
  var REPL, args, cmd, comm, credentials, env, fs, ipc, k, net, netBinding, nworkers, server, socket, spawnWorker, v, watch, websocket, workers, _ref, _ref2, _ref3, _ref4, _ref5, _ref6;
  if (options == null) {
    options = {};
  }
  net = require('net');
  fs = require('fs');
  (_ref = options.port) != null ? _ref : options.port = 80;
  nworkers = options.workers || require('os').cpus().length;
  (_ref2 = options.ipc) != null ? _ref2 : options.ipc = '.ipc';
  if (process.env._NODE_WORKER_FOR_) {
    process.log = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      args[0] = ("" + (Date.now()) + " WORKER " + process.pid + ": ") + args[0];
      return console.error.apply(console, args);
    };
    if (options.sslKey) {
      credentials = {
        key: fs.readFileSync(options.sslKey, 'utf8'),
        cert: fs.readFileSync(options.sslCert, 'utf8')
      };
      server = require('https').createServer(credentials);
    } else {
      server = require('http').createServer();
    }
    server.on('request', app.getHandler(server));
    if (options.websocket) {
      websocket = require('io').listen(server, {
        flashPolicyServer: false,
        transports: ['websocket', 'xhr-polling']
      });
      websocket.on('connection', options.websocket);
    }
    if (options.shutdownTimeout) {
      process.on('SIGQUIT', function() {
        this.log('shutting down...');
        if (server.connections) {
          server.watcher.stop();
          setInterval((function() {
            return server.connections || process.exit(0);
          }), 2000);
          return setTimeout((function() {
            return process.exit(0);
          }), options.shutdownTimeout);
        } else {
          return this.exit(0);
        }
      });
    }
    process.on('exit', function() {
      return this.log('shutdown');
    });
    process.on('uncaughtException', function(err) {
      this.log("EXCEPTION: " + (err.stack || err.message));
      return this.exit(1);
    });
    comm = net.createConnection(options.ipc);
    comm.on('connect', function() {
      return comm.setEncoding('utf8');
    });
    comm.on('data', framing.bind(comm));
    comm.on('message', (_ref3 = app.messageHandler) != null ? _ref3.bind(process, websocket != null ? (_ref4 = websocket.broadcast) != null ? _ref4.bind(websocket) : void 0 : void 0) : void 0);
    comm.once('fd', function(fd) {
      server.listenFD(fd);
      return process.publish('register');
    });
    comm.once('end', function() {
      return process.exit();
    });
    process.publish = function(channel, message) {
      var data;
      data = {
        from: this.pid,
        channel: channel,
        data: message
      };
      return comm.write(JSON.stringify(data));
    };
  } else {
    process.log = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      args[0] = "MASTER: " + args[0];
      return console.error.apply(console, args);
    };
    netBinding = process.binding('net');
    socket = netBinding.socket('tcp' + (netBinding.isIP(options.host) === 6 ? 6 : 4));
    netBinding.bind(socket, options.port);
    netBinding.listen(socket, options.connections || 1024);
    if (process.getuid() === 0) {
      if (options.uid) {
        process.setuid(options.uid);
      }
      if (options.gid) {
        process.setgid(options.gid);
      }
    }
    if (options.pwd) {
      process.chdir(options.pwd);
    }
    workers = {};
    args = options.argv || process.argv;
    env = {};
    _ref5 = process.env;
    for (k in _ref5) {
      if (!__hasProp.call(_ref5, k)) continue;
      v = _ref5[k];
      env[k] = v;
    }
    _ref6 = options.env || {};
    for (k in _ref6) {
      if (!__hasProp.call(_ref6, k)) continue;
      v = _ref6[k];
      env[k] = v;
    }
    spawnWorker = function() {
      var worker;
      env._NODE_WORKER_FOR_ = process.pid;
      return worker = require('child_process').spawn(args[0], args.slice(1), {
        env: env,
        customFds: [0, process.stdout, process.stderr]
      });
    };
    process.publish = function(channel, message) {
      var data, pid, worker;
      data = JSON.stringify({
        from: null,
        channel: channel,
        data: message
      });
      for (pid in workers) {
        worker = workers[pid];
        worker.write(data);
      }
    };
    ipc = net.createServer(function(stream) {
      stream.setEncoding('utf8');
      stream.write('{"foo": "bar"}', 'ascii', socket);
      stream.on('data', framing.bind(stream));
      stream.on('message', function(data) {
        var pid, worker;
        if (data.channel === 'bcast') {
          data = JSON.stringify(data);
          for (pid in workers) {
            worker = workers[pid];
            worker.write(data);
          }
        } else if (data.channel === 'register') {
          workers[data.from] = stream;
          process.log("WORKER " + data.from + " started and listening to *:" + options.port);
        }
      });
      return stream.on('end', function() {
        var pid, worker;
        for (pid in workers) {
          worker = workers[pid];
          if (worker === stream) {
            delete workers[pid];
          }
        }
        if (nworkers > Object.keys(workers).length) {
          spawnWorker();
        }
      });
    });
    ipc.listen(options.ipc, function() {
      var id;
      for (id = 0; (0 <= nworkers ? id < nworkers : id > nworkers); (0 <= nworkers ? id += 1 : id -= 1)) {
        spawnWorker();
      }
    });
    ['SIGINT', 'SIGTERM', 'SIGKILL', 'SIGUSR2', 'SIGHUP', 'SIGQUIT', 'exit'].forEach(function(signal) {
      return process.on(signal, function() {
        var pid, worker;
        this.log("signalled " + signal);
        for (pid in workers) {
          worker = workers[pid];
          try {
            process.log("sending " + signal + " to WORKER " + pid);
            process.kill(pid, signal);
          } catch (err) {
            process.log("sending EMERGENCY exit to WORKER " + pid);
            worker.emit('exit');
          }
        }
        if (signal !== 'exit' && signal !== 'SIGHUP' && signal !== 'SIGQUIT') {
          return process.exit();
        }
      });
    });
    if (options.repl) {
      REPL = function(stream) {
        var repl;
        repl = require('repl').start('node>', stream);
        return _.extend(repl.context, {
          shutdown: function() {
            nworkers = 0;
            process.kill(process.pid, 'SIGQUIT');
            return process.exit(0);
          },
          stop: function() {
            return process.exit(0);
          },
          respawn: function() {
            return process.kill(process.pid, 'SIGQUIT');
          },
          restart: function() {
            return process.kill(process.pid, 'SIGHUP');
          },
          spawn: function(n) {
            if (n > 0) {
              while (n-- > 0) {
                spawnWorker();
                ++nworkers;
              }
            } else if (n < 0) {
              nworkers = Math.max(0, nworkers + n);
              process.kill(process.pid, 'SIGQUIT');
            }
          },
          mem: function() {
            return console.log(process.memoryUsage());
          },
          status: function() {
            var pid, status, worker;
            for (pid in workers) {
              worker = workers[pid];
              try {
                process.kill(pid, 0);
                status = 'alive';
              } catch (err) {
                if (ESRCH === err.errno) {
                  status = 'dead';
                } else {
                  throw err;
                }
              }
              console.log("STATUS for " + pid + " is " + status);
            }
          }
        });
      };
      if (options.repl === true) {
        process.stdin.on('close', process.exit);
        REPL();
        process.log("REPL running in the console. Use CTRL+C to stop.");
      } else {
        net.createServer(REPL).listen(options.repl);
        if (typeof options.repl === 'number') {
          process.log("REPL running on 127.0.0.1:" + options.repl + ". Use CTRL+C to stop.");
        } else {
          process.log("REPL running on " + options.repl + ". Use CTRL+C to stop.");
        }
      }
    }
    if (options.watch) {
      watch = options.watch.join(' ');
      cmd = "find " + watch;
      require('child_process').exec(cmd, function(err, out) {
        var files, restarting;
        restarting = false;
        files = out.trim().split('\n');
        return files.forEach(function(file) {
          return fs.watchFile(file, {
            interval: options.watch || 100
          }, function(curr, prev) {
            if (restarting) {
              return;
            }
            if (curr.mtime > prev.mtime) {
              process.log("" + file + " has changed, respawning");
              restarting = true;
              process.kill(process.pid, 'SIGQUIT');
              return restarting = false;
            }
          });
        });
      });
    }
    process.on('uncaughtException', function(err) {
      process.log("EXCEPTION: " + (err.stack || err.message));
      return process.kill(process.pid, 'SIGHUP');
    });
  }
};