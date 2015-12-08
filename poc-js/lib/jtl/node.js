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
    var self  = this;
    var value = self.value();
    var type  = internal.valueType(value);
    var path  = self.path();
    var doc   = self.doc()

    if (type == 'array') {
      return value.map( function ( val, i ) {
        var newPath = path.slice(0, -1);
        newPath.push(i);
        return doc.findNode( newPath );
      } );
    } else if (type == 'object') {
      return internal.keys(value).map( function( key, i ) {
        var newPath = path.slice(0, -1);
        newPath.push(key);
        return doc.findNode( newPath );
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
