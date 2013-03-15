(function() {
	/**
	* Module dependencies.
	*/
 
	"use strict";
	var express = require('express'),
		routes = require('./routes'),
		http = require('http'),
		path = require('path'),
		hbs = require ('hbs'),
		models = require('./server/models/models'),
		colors = require('colors');
		

	var app = express();

	app.configure(function(){
		app.set('port', process.env.PORT || 3000);
		app.set('views', __dirname + '/server/views');
		app.engine('html', hbs.__express);
		app.set('view engine', 'html');
		app.use(express.favicon());
		app.use(express.logger('dev'));
		app.use(express.bodyParser());
		app.use(express.methodOverride());
		app.use(app.router);
		app.use(express.static(path.join(__dirname, 'public')));
	});

	app.configure('development', function(){
		app.use(express.errorHandler());
	});

	app.get('/', routes.index);

	var server = app.listen(app.get('port'), function(){
		var msg = "Express server listening on port " + app.get('port');
		console.log(msg.bold.cyan);
	});


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
					case TYPES.UPDATE:
					case TYPES.DELETE:
						var payload = {};
						payload[data.type] = results[0];
						results = payload;
					break;
					case TYPES.FIND_ALL:
						var payload = {};
						var rows = results[0]
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