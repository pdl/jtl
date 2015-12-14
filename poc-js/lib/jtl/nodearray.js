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

  children: function() { return this.contents() },

  child: function(which) {

    var contents = this.contents();

    which = ( which >= 0 ? which : which + contents.length ); // JS doesn't understand negative indexes

    if (
      'number' !== internal.valueType( which )
      || which !== parseInt ( which )
      || which < 0
      || which >= contents.length
    ) {
      return undefined
    }

    return contents[which];
  }

} );

exports = module.exports = { package: NodeArray, new: function(contents){ return new NodeArray(contents); } };

internal.nodeArray = module.exports;
