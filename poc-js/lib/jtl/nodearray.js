var util     = require('util');
var internal = require('./internal');
var nodeList = require('./nodelist');


var NodeArray = internal.Class( internal.nodeList.package, {
  constructor: function(contents) {
    var self = this;
    self.contents(contents);
    return self;
  },

  $packageName: 'jtl/nodearray',

  type: function() { return 'nodeArray' },

  children: function() { return this.contents() }

} );

exports = module.exports = { package: NodeArray, new: function(contents){ return new NodeArray(contents); } };

internal.nodeArray = module.exports;
