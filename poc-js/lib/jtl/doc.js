var internal = require('./internal');
var node     = require('./node');

var Doc = internal.Class( node.package, {

  $packageName: 'jtl/doc',

  constructor: function(contents) {
    var self      = this;
    self.contents(contents);
    self.$package().$super.call( self, self, [] );
    return self;
  },

  contents: internal.attribute('contents'),

  value: function() {
    return this.contents();
  },

  type: function() { // overwritten for speed
    return internal.valueType(this.contents());
  },

  parent: function() { // overwritten for speed
    return undefined;
  },

  findNode: function(path) {
    return node.new(this, path);
  },

  findValue: function(path) {
    var self = this;

    if ( !path.length ) {
      return self.contents();
    }

    var current = [ self.contents() ];

    for (
      var i = 0;
      i < path.length;
      i++
    ) {
      var type = typeof ( current[0] );

      if ( type =='array' ) {
        current = [ current[0][path[i]] ];
      } else if ( type == 'object' ) {
        current = [ current[0][path[i]] ];
      } else {
        internal.throwError('ImplementationError');
      }
    }

    return current[0];
  }
} );

exports = module.exports = { package: Doc, new: function(contents){ return new Doc(contents); } };

internal.doc = module.exports;
