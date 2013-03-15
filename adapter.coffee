# Initializer for Models
window.Models = {}
SOCKET = "/" # Served off the root of our app
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

DS.SocketAdapter = DS.RESTAdapter.extend(
  socket: `undefined`
  
  #
  #		* A hashmap of individual requests. Key/value pairs of a UUID
  #		* and a hashmap with the parameters passed in based on the 
  #		* request type. Includes "requestType" and "callback" in addition.
  #		* RequestType is simply an enum value from TYPES (Defined below)
  #		* and callback is a function that takes two parameters: request and response.
  #		* the `ws.on('ember-data`) method receives a hashmap with two keys: UUID and data.
  #		* The UUID is used to fetch the original request from this.requests, and that request
  #		* is passed into the request's callback with the original request as well.
  #		* Finally, the request payload is removed from the requests hashmap.
  #		
  requests: `undefined`
  generateUuid: ->
    S4 = ->
      # 65536
      Math.floor(Math.random() * 0x10000).toString 16

    S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4()

  send: (request) ->
    request.uuid = @generateUuid()
    request.context = this
    @get("requests")[request.uuid] = request
    data =
      uuid: request.uuid
      action: request.requestType
      type: @rootForType(request.type)

    if request.record isnt `undefined`
      data.record = @serialize(request.record,
        includeId: true
      )
    @socket.emit "ember-data", data

  find: (store, type, id) ->
    @send
      store: store
      type: type
      id: id
      requestType: TYPES.FIND
      callback: (req, res) ->
        Ember.run req.context, ->
          @didFindRecord req.store, req.type, res, req.id



  findMany: (store, type, ids, query) ->
    
    # ids = this.serializeIds(ids);
    @send
      store: store
      type: type
      ids: ids
      query: query
      requestType: TYPES.FIND_MANY
      callback: (req, res) ->
        Ember.run req.context, ->
          @didFindMany req.store, req.type, res



  findQuery: (store, type, query, recordArray) ->
    @send
      store: store
      type: type
      query: query
      recordArray: recordArray
      requestType: TYPES.FIND_QUERY
      callback: (req, res) ->
        Ember.run req.context, ->
          @didFindQuery req.store, req.type, res, req.recordArray



  findAll: (store, type, since) ->
    @send
      store: store
      type: type
      since: @sinceQuery(since)
      requestType: TYPES.FIND_ALL
      callback: (req, res) ->
        Ember.run req.context, ->
          @didFindAll req.store, req.type, res



  createRecord: (store, type, record) ->
    @send
      store: store
      type: type
      record: record
      requestType: TYPES.CREATE
      callback: (req, res) ->
        Ember.run req.context, ->
          @didCreateRecord req.store, req.type, req.record, res



  createRecords: (store, type, records) ->
    @_super store, type, records

  updateRecord: (store, type, record) ->
    @send
      store: store
      type: type
      record: record
      requestType: TYPES.UPDATE
      callback: (req, res) ->
        Ember.run req.context, ->
          @didSaveRecord req.store, req.type, req.record, res



  updateRecords: (store, type, records) ->
    @_super store, type, records

  deleteRecord: (store, type, record) ->
    @send
      store: store
      type: type
      record: record
      requestType: TYPES.DELETE
      callback: (req, res) ->
        Ember.run req.context, ->
          @didSaveRecord req.store, req.type, req.record, res



  deleteRecords: (store, type, records) ->
    @_super store, type, records

  init: ->
    @_super()
    context = this
    @set "requests", {}
    ws = io.connect("//" + location.host)
    
    # For all standard socket.io client events, see https://github.com/LearnBoost/socket.io-client
    
    #
    #			* Returned payload has the following key/value pairs:
    #			* {
    #			* 	uuid: [UUID from above],
    #			* 	data: [payload response],
    #			* }
    #			
    ws.on "ember-data", (payload) ->
      uuid = payload.uuid
      request = context.get("requests")[uuid]
      request.callback request, payload.data
      
      # Cleanup
      context.get("requests")[uuid] = `undefined`

    ws.on "disconnect", ->

    @set "socket", ws
)

# Create ember-data datastore and define our adapter
App.store = DS.Store.create(
  revision: 11
  adapter: DS.SocketAdapter.create({})
)

# Convenience method for handling saves of state via the model.
DS.Model.reopen save: ->
  App.store.commit()
  this
