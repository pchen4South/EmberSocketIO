// Generated by CoffeeScript 1.4.0

(function() {
  "use strict";
  var TYPES, app, async, colors, express, http, io, modelActions, models, path, server;
  express = require("express");
  http = require("http");
  path = require("path");
  colors = require("colors");
  models = require("./models/models");
  app = express();
  app.configure(function() {
    app.set("port", 80);
    app.use(express.favicon());
    app.use(express.logger("dev"));
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(express["static"](__dirname + "/public"));
    return app.use(express["static"](__dirname));
  });
  app.configure("development", function() {
    return app.use(express.errorHandler());
  });
  app.get("/", function(req, res) {
    return res.sendfile(__dirname + "/index.html");
  });
  server = app.listen(app.get("port"), function() {
    var msg;
    msg = void 0;
    msg = "Express server listening on port " + app.get("port");
    return console.log(msg.bold.cyan);
  });
  /*
    Socket.IO server implementation *
  */

  io = require("socket.io").listen(server);
  TYPES = {
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
  modelActions = function(data) {
    var capitalize, functionArray, results;
    capitalize = function(string) {
      return string.charAt(0).toUpperCase() + string.slice(1);
    };
    results = [];
    /*
        We extract the functions used in the for loop below
        into functionArray for optimization purposes.
        This also makes it pass JSHint
    */

    functionArray = {
      CREATE: function(callback) {
        return models[capitalize(data.type)].create(data.record, function(err, newModel) {
          if (err) {
            return callback(err, null);
          } else {
            return callback(null, newModel);
          }
        });
      },
      UPDATE: function(callback) {
        return models[capitalize(data.type)].findOneAndUpdate({
          _id: data.record.id
        }, {
          $set: data.record
        }, callback);
      },
      DELETE: function(callback) {
        return models[capitalize(data.type)].findOneAndRemove({
          _id: data.record.id
        }, callback);
      },
      FIND_ALL: function(callback) {
        return models[capitalize(data.type)].find({}, callback);
      },
      FIND: function(callback) {
        return models[capitalize(data.type)].find({
          _id: data.id
        }, callback);
      }
    };
    switch (data.action) {
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
  async = require("async");
  return io.sockets.on("connection", function(socket) {
    return socket.on("ember-data", function(data) {
      var actions;
      if (data.record !== undefined) {
        data.data = [data.record];
      }
      actions = modelActions(data);
      return async.parallel(actions, function(err, results) {
        var i, payload, response, row, rows;
        if (err) {
          console.warn(err);
        }
        switch (data.action) {
          case TYPES.CREATE:
            payload = {};
            payload[data.type] = results[0].toObject({
              transform: function(doc, ret, options) {
                delete ret.__v;
                ret.id = ret._id;
                delete ret._id;
                return ret;
              }
            });
            results = payload;
            break;
          case TYPES.UPDATE:
          case TYPES.DELETE:
            payload = {};
            payload[data.type] = results[0].toObject({
              transform: function(doc, ret, options) {
                delete ret.__v;
                ret.id = ret._id;
                delete ret._id;
                return ret;
              }
            });
            results = payload;
            break;
          case TYPES.FIND_ALL:
            payload = {};
            rows = results[0];
            i = 0;
            while (i < rows.length) {
              row = rows[i].toObject({
                transform: function(doc, ret, options) {
                  delete ret.__v;
                  ret.id = ret._id;
                  delete ret._id;
                  return ret;
                }
              });
              console.log("ROW::", row);
              rows[i] = row;
              i++;
            }
            payload[data.type + "s"] = rows;
            results = payload;
            break;
          case TYPES.FIND:
            payload = {};
            payload[data.type] = results[0];
            results = payload;
            break;
          default:
            throw "Unknown action " + data.action;
        }
        response = {
          uuid: data.uuid,
          action: data.action,
          type: data.type,
          data: results
        };
        console.log("RESPONSE::", response);
        socket.emit("ember-data", response);
        return socket.broadcast.emit("update", response);
      });
    });
  });
})();
