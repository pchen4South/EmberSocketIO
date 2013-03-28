"use strict"
express = require("express")
http = require("http")
path = require("path")
colors = require("colors")
models = require("./models/models")
ObjectId = require('mongoose').Types.ObjectId

app = express()

app.configure ->
  app.set "port", 80
  app.use express.favicon()
  app.use express.logger("dev")
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express["static"](__dirname + "/public")
  app.use express["static"](__dirname)

app.configure "development", ->
  app.use express.errorHandler()

app.get "/", (req, res) ->
  res.sendfile __dirname + "/index.html"

server = app.listen(app.get("port"), ->
  msg = "Express server listening on port " + app.get("port")
  console.log msg.bold.cyan
)

#
#    Socket.IO server implementation *
#  

io = require("socket.io").listen(server)
TYPES =
  CREATE: "CREATE"
  CREATES: "CREATES"
  UPDATE: "UPDATE"
  UPDATES: "UPDATES"
  DELETE: "DELETE"
  DELETES: "DELETES"
  FIND: "FIND"
  FIND_MANY: "FIND_MANY"
  FIND_QUERY: "FIND_QUERY"
  FIND_ALL: "FIND_ALL"

  
# SOCKET.io OPERATIONS
io.sockets.on "connection", (socket) ->
  socket.on "ember-data", (data) ->
    data.data = [data.record]  if data.record isnt `undefined`
    payload = {}
    switch data.action
      when TYPES.CREATE
        CREATE(data, socket, CREATE_Callback)
      when TYPES.UPDATE
        UPDATE(data, socket, UPDATE_Callback) 
      when TYPES.DELETE
        DELETE(data, socket, DELETE_Callback)
      when TYPES.FIND_ALL
        FIND_ALL(data, socket, FIND_ALL_Callback)
      when TYPES.FIND
        FIND(data, socket, FIND_CallBack)
      else
        throw "Unknown action " + data.action    
  
# DATABASE COMMS Functions
CREATE = (data, socket, callback) ->
  models[capitalize(data.type)].create data.record,
    (err, results)->
      dbCallBack(err, results, callback, socket, data)
  
UPDATE = (data, socket, callback) ->
  models[capitalize(data.type)].findOneAndUpdate
    _id: data.record.id
  ,
    $set: data.record
  , (err, results)->
      dbCallBack(err, results, callback, socket, data)

DELETE = (data, socket, callback) ->
  models[capitalize(data.type)].findOneAndRemove
    _id: data.record.id
    (err, results)->
      callback(data, socket, results)
    
FIND_ALL = (data, socket, callback) ->
  models[capitalize(data.type)].find {}, (err, results)->
    dbCallBack(err, results, callback, socket, data)

FIND =  (data, socket, callback) ->
  models[capitalize(data.type)].findById
    _id: ObjectId.fromString(data.id)
    (err, results)->
      dbCallBack(err, results, callback, socket, data)
  
# SOCKET OPERATION callbacks

FIND_ALL_Callback = (data, socket, models) ->
  payload = {}
  results = models
  i = 0
  while i < results.length
    eachResult = results[i].toObject(transform: databaseResponseCleanup)
    results[i] = eachResult
    i++
  payload[data.type + "s"] = results
  response = formatResponse(data, payload)
  socket.emit "ember-data", response

CREATE_Callback = (data, socket, model) ->
  response = callbackHelper(data, socket, model)  
  socket.broadcast.emit "create", response

UPDATE_Callback = (data, socket, model)->
  response = callbackHelper(data, socket, model)  
  socket.broadcast.emit "update", response

DELETE_Callback = (data, socket, model)->
  response = callbackHelper(data, socket, model)  
  socket.broadcast.emit "delete", response

FIND_Callback = (data, socket, model)->
  if model
    response = callbackHelper(data, socket, model)  
    socket.emit "ember-data", response
  else socket.emit "ember-data", "model not found"
  
# HELPER methods  
capitalize = (string) -> string.charAt(0).toUpperCase() + string.slice(1)   

dbCallBack = (err, results, callback, socket, data) ->
  if err then console.log err
  else callback(data, socket, results)
  return false 
  
formatResponse = (data, results)->
  response =
    uuid: data.uuid
    action: data.action
    type: data.type
    data: results  

databaseResponseCleanup = (doc, ret, options) ->
  delete ret.__v
  ret.id = ret._id
  delete ret._id
  return ret

callbackHelper = (data, socket, model) ->
  payload = {}
  results = model
  payload[data.type] = model.toObject(transform: databaseResponseCleanup)
  response = formatResponse(data, payload)
  socket.emit "ember-data", response
  return response

 