var internal = require('./internal');

var Node = internal.Class( {

  $packageName: 'jtl/node',

  constructor: function(doc, path){
    var self = this;
    self.doc(doc);
    self.path(path);
    return self;
  },

  doc: internal.attribute('doc'),

  path: internal.attribute('path'),

  value: function() {
    return this.doc().findValue( this.path() );
  },

  type: function() {
    return internal.valueType(this.value());
  },

  parent: function() {
    var self = this;
    if ( self.path.length ) {
      var parentPath = self.path.slice(0,-1);
      return self.doc().findNode(parentPath);
    }
    return undefined;
  },

  children: function() {
    var self = this;
    var type = self.type();
    var path = self.path();
    var doc  = self.doc()

    if (type == 'array') {
      var value = self.value;

      return value.map( function ( i , val ) {
        return doc.findNode( path.slice(0).push(i) );
      } );
    } else if (type == 'object') {
      var value = self.value();

      return internal.keys(value).map( function( i, key ) {
        return doc.findNode( path.slice(0).push(key) );
      } );
    }

    return undef;
  },

  name: function() {
    var self   = this;
    var parent = self.parent();
    if ( parent && parent.type() == 'object' ) {
      return self.path[-1];
    }
    return undefined;
  },

  index: function() {
    var self   = this;
    var parent = self.parent();
    if ( parent && parent.type() == 'array' ) {
      return self.path[-1];
    }
    return undefined;
  }
} );

exports = module.exports = { new: function(doc, path){ return new Node(doc, path); }, package: Node };

require('./doc');
