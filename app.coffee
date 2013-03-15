(->
  "use strict"
  express = require("express")
  http = require("http")
  path = require("path")
  colors = require("colors")
  models = require("./models/models")
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
    msg = undefined
    msg = "Express server listening on port " + app.get("port")
    console.log msg.bold.cyan
  )
  
  #
  #    Socket.IO server implementation *
  #  
  
  ###
  Socket.IO server implementation *
  ###
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

  modelActions = (data) ->
    capitalize = (string) ->
      string.charAt(0).toUpperCase() + string.slice(1)

    results = []
    
    ###
    We extract the functions used in the for loop below
    into functionArray for optimization purposes.
    This also makes it pass JSHint
    ###
    functionArray =
      CREATE: (callback) ->
        models[capitalize(data.type)].create data.record, (err, newModel) ->
          if err
            callback err, null
          else
            callback null, newModel

      UPDATE: (callback) ->
        models[capitalize(data.type)].findOneAndUpdate
          _id: data.record.id
        ,
          $set: data.record
        , callback

      DELETE: (callback) ->
        models[capitalize(data.type)].findOneAndRemove
          _id: data.record.id
        , callback

      FIND_ALL: (callback) ->
        models[capitalize(data.type)].find {}, callback

      FIND: (callback) ->
        models[capitalize(data.type)].find
          _id: data.id
        , callback

    switch data.action
      when TYPES.CREATE
        results.push functionArray.CREATE
      when TYPES.UPDATE
        results.push functionArray.UPDATE
      when TYPES.DELETE
        results.push functionArray.DELETE
      when TYPES.FIND_ALL
        results.push functionArray.FIND_ALL
      when TYPES.FIND
        results.push functionArray.FIND
      else
        throw "Unknown action " + data.action
    results

  async = require("async")
  io.sockets.on "connection", (socket) ->
    socket.on "ember-data", (data) ->
      data.data = [data.record]  if data.record isnt `undefined`
      actions = modelActions(data)
      async.parallel actions, (err, results) ->
        console.warn err  if err
        switch data.action
          when TYPES.CREATE
            payload = {}
            payload[data.type] = results[0].toObject(transform: (doc, ret, options) ->
              delete ret.__v
              ret.id = ret._id
              delete ret._id
              ret
            )
            results = payload
          when TYPES.UPDATE, TYPES.DELETE
            payload = {}
            payload[data.type] = results[0].toObject(transform: (doc, ret, options) ->
              delete ret.__v
              ret.id = ret._id
              delete ret._id
              ret
            )
            results = payload
          when TYPES.FIND_ALL
            payload = {}
            rows = results[0]
            i = 0
            while i < rows.length
              row = rows[i].toObject(transform: (doc, ret, options) ->
                delete ret.__v
                ret.id = ret._id
                delete ret._id
                ret
              )
              console.log "ROW::", row
              rows[i] = row
              i++
            payload[data.type + "s"] = rows
            results = payload
          when TYPES.FIND
            payload = {}
            payload[data.type] = results[0]
            results = payload
          else
            throw "Unknown action " + data.action
        response =
          uuid: data.uuid
          action: data.action
          type: data.type
          data: results
        console.log "RESPONSE::", response
        socket.emit "ember-data", response
        socket.broadcast.emit "update", response
    

)()