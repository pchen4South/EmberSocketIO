// Generated by CoffeeScript 1.4.0

(function() {
  /*
    Module dependencies.
  */

  "use strict";
  var TYPES, app, async, colors, express, http, io, modelActions, models, path, server;
  express = require("express");
  http = require("http");
  path = require("path");
  colors = require("colors");
  models = require('./models/models');
  app = express();
  app.configure(function() {
    app.set("port", 80);
    app.use(express.favicon());
    app.use(express.logger("dev"));
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(express["static"](__dirname + '/public'));
    return app.use(express["static"](__dirname));
  });
  app.configure("development", function() {
    return app.use(express.errorHandler());
  });
  app.get('/', function(req, res) {
    return res.sendfile(__dirname + '/index.html');
  });
  server = app.listen(app.get("port"), function() {
    var msg;
    msg = "Express server listening on port " + app.get("port");
    return console.log(msg.bold.cyan);
  });
  /*
    Socket.IO server implementation *
  */

	/** Socket.IO server implementation **/
	var io = require('socket.io').listen(server);
	
	var TYPES = {
		CREATE: "CREATE",
		CREATES: "CREATES",
		UPDATE: "UPDATE",
		UPDATES: "UPDATES",
		DELETE: "DELETE",
		DELETES: "DELETES",
		FIND: "FIND",
		FIND_MANY: "FIND_MANY",
		FIND_QUERY: "FIND_QUERY",
		FIND_ALL: "FIND_ALL"
	};
	
	var modelActions = function(data) {
		var capitalize =  function(string) {
			return string.charAt(0).toUpperCase() + string.slice(1);
		}
		
		
		var results = [];
		/**
		 * We extract the functions used in the for loop below
		 * into functionArray for optimization purposes.
		 * This also makes it pass JSHint
		**/
		var functionArray = {
			CREATE: function(callback) {
				models[capitalize(data.type)].create(data.record, function(err, newModel) {
					if (err) {
						callback(err, null);
					} else {
						callback(null, newModel);
					}
				});
			},
			UPDATE: function(callback) {
				models[capitalize(data.type)].update({_id: data.record.id}, { $set: data.record}, callback);
			},
			DELETE: function(callback) {
				models[capitalize(data.type)].remove({ _id: data.record.id}, function(err) {
					callback(err, null);
				});
			},
			FIND_ALL: function(callback) {
				models[capitalize(data.type)].find({}, callback);
			},
      FIND: function(callback){
        console.log("DATA: ", data);
        models[capitalize(data.type)].find({ _id: data.id}, callback);
      }
      
		};
		
		switch(data.action) {
			case TYPES.CREATE:
				results.push(functionArray.CREATE);
				break;
			case TYPES.UPDATE:
				results.push(functionArray.UPDATE);
				break;
			case TYPES.DELETE:
				results.push(functionArray.DELETE);
				break;
			case TYPES.FIND_ALL:
				results.push(functionArray.FIND_ALL);
				break;
      case TYPES.FIND:
        results.push(functionArray.FIND);
        break;
			default:
				throw "Unknown action " + data.action;
		}
		
		
		return results;
	};

	var async = require('async');
	io.sockets.on('connection', function(socket) {
		socket.on('ember-data', function(data) {
			if (data.record !== undefined) {
				data.data = [data.record];
			}
			
			var actions = modelActions(data);
			
			async.parallel(actions, function(err, results) {
				if (err) {
					console.warn(err);
				}
				
				switch (data.action) {
					case TYPES.CREATE:
            var payload = {};
						payload[data.type] = results[0].toObject({
              transform: function(doc, ret, options) {
								delete ret.__v;
								ret.id = ret._id;
								delete ret._id;
							}});
            results = payload;
          break;
          
					case TYPES.UPDATE:
					case TYPES.DELETE:
						var payload = {};
						payload[data.type] = results[0];
						results = payload;
					break;
					case TYPES.FIND_ALL:
						var payload = {};
						var rows = results[0]
            console.log("ROWS", rows);
						for (var i = 0; i < rows.length; i++) {
							var row = rows[i].toObject({transform: function(doc, ret, options) {
								delete ret.__v;
								ret.id = ret._id;
								delete ret._id;
							}});
							console.log('ROW::',row);
							rows[i] = row;
						}
						payload[data.type + 's'] = rows;
						results = payload;
					break;
          case TYPES.FIND:
            var payload = {};
						payload[data.type] = results[0];
						results = payload;
          break;
					default:
						throw "Unknown action " + data.action;
				}
				
				var response = {
					uuid: data.uuid,
					action: data.action,
					type: data.type,
					data: results
				};
				console.log("RESPONSE::",response);
				socket.emit('ember-data', response);
			});
		});
	});
}());