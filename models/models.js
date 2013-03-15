var env = 'development'
  , config = require('../config/DBConfig')[env]
  , mongoose = require('mongoose');

// Bootstrap db connection
mongoose.connect(config.db);

var Boxs = new mongoose.Schema({
    height     : Number
  , width      : Number
  , left       : Number
  , top        : Number
  , text       : String
});

var Box = mongoose.model('Box', Boxs);

module.exports = {'Box': Box};