window.App = Ember.Application.create()

App.Box = DS.Model.extend
  height: DS.attr 'number'
  width:  DS.attr 'number'
  left:   DS.attr 'number'
  top:    DS.attr 'number'
  text:   DS.attr 'string'
  selected: DS.attr 'boolean', {defaultValue: false}
  
#router
App.Router.map () ->
  @resource "boxs" , ->
    @resource "box",
      path: ':box_id'
    
App.IndexRoute = Em.Route.extend
  redirect: ->
    @replaceWith('boxs')

App.BoxsRoute = Em.Route.extend    
  model: ->
    App.Box.find()
  setupController: (controller, model)->
    controller.set('content', model)
    @_super()
    
App.BoxsController = Em.ArrayController.extend
  content: []
  selBox: null
  addBox: ->
    newBox = App.Box.createRecord
      text: 'newBox'
      height: 200
      width: 200
    newBox.save()
  selectBox: (box) ->
    for obj in @get('content').toArray()
      obj.set('selected', false)
    box.set('selected', true)
    @set('selBox', box)
  delBox: (box)->
    box.deleteRecord()
    box.save()
  saveText: ->
    App.store.commit()
  
    

App.BoxView = Em.View.extend
  templateName: 'box'
  tagName: 'div'
  classNames: ['box']
  classNameBindings: ['selected']
  attributeBindings: ['style']
  controllerBinding: App.BoxController
  selected: (->
    return @get('content.selected')
  ).property('content.selected')
  click: (event)->
    console.log @get('controller')
    window.box = @get('content')
    @get('controller').selectBox(@get('content'))
  style: (->
       height = @get('content.height')
       width = @get('content.width')
       top = @get('content.top')
       left = @get('content.left')
       heightString = "height:#{height}px;"
       widthString="width:#{width}px;"
       topString="top:#{top}px;"
       leftString="left:#{left}px;"
       return heightString + widthString + topString + leftString
    ).property('content.height', 'content.width', 'content.top', 'content.left').cacheable()
  
  
  
  
  
  
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

DS.SocketAdapter = DS.RESTAdapter.extend
  socket: undefined
  requests: undefined
  generateUuid: ->
    S4 = ->
      Math.floor(Math.random() * 0x10000).toString 16
    S4() + S4() 

  send: (request) ->
    request.uuid = @generateUuid()
    request.context = this
    @get("requests")[request.uuid] = request       
    data =
      uuid: request.uuid
      action: request.requestType
      type: @rootForType(request.type)

    if request.record isnt undefined
      data.record = @serialize(request.record,
        includeId: true
      )
    if request.id isnt undefined
      data.id = request.id
      
    if request.query isnt undefined
      data.query = request.query       
    if request.ids isnt undefined
      data.ids = request.ids
      
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

  updateRecord: (store, type, record) ->
    @send
      store: store
      type: type
      record: record
      requestType: TYPES.UPDATE
      callback: (req, res) ->
        Ember.run req.context, ->
          @didSaveRecord req.store, req.type, req.record, res

  deleteRecord: (store, type, record) ->
    @send
      store: store
      type: type
      record: record
      requestType: TYPES.DELETE
      callback: (req, res) ->
        Ember.run req.context, ->
          @didSaveRecord req.store, req.type, req.record

  init: ->
    @_super()
    context = this
    @set "requests", {}
    ws = io.connect("//" + location.host)
    window.reqs = @get 'requests'
    #
    #			* Returned payload has the following key/value pairs:
    #			* {
    #			* 	uuid: [UUID from above],
    #			* 	data: [payload response],
    #			* }
    
    ws.on "ember-data", (payload) ->
      uuid = payload.uuid
      request = context.get("requests")[uuid]
      if payload.data
        request.callback request, payload.data
      # Cleanup
      #context.get("requests")[uuid] = `undefined`
    ws.on "delete", (payload) ->
      boxId = payload.data['box'].id
      box = App.store.find(App.Box, boxId)
      App.store.unloadRecord(box)
    ws.on "create", (payload) ->
      window.pay = payload
      App.store.load(App.Box, payload.data[payload.type])
    ws.on "update", (payload) ->
      App.store.load(App.Box, payload.data[payload.type])
    ws.on "disconnect", ->
    @set "socket", ws

DS.SocketAdapter.map 'App.Box',
  box: { key: 'boxs' }

# Create ember-data datastore and define our adapter
App.store = DS.Store.create
  revision: 11
  adapter: DS.SocketAdapter.create()

# Convenience method for handling saves of state via the model.
DS.Model.reopen save: ->
  App.store.commit()
  this
