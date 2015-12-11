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
    if ( self.path().length ) {
      var parentPath = self.path().slice(0,-1);
      return self.doc().findNode(parentPath);
    }
    return undefined;
  },

  child: function (which) {
    var self  = this;
    var value = self.value();
    var type  = internal.valueType(value);
    var path  = self.path();
    var doc   = self.doc()


    if (type == 'array') {
      which = ( which >= 0 ? which : which + value.length ); // JS doesn't understand negative indexes

      if (
        'number' !== internal.valueType( which )
        || which !== parseInt ( which )
        || which < 0
        || which >= value.length
      ) {
        return undefined
      }

      var newPath = path.slice(0, -1);
      newPath.push(which);

      return doc.findNode( newPath );

    } else if (type == 'object') {

      if (!value.hasOwnProperty(which)) {
        return undefined;
      }

      var newPath = path.slice(0, -1);
      newPath.push(which);

      return doc.findNode( newPath );
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

    return undefined;
  },

  name: function() {
    var self   = this;
    var parent = self.parent();
    if ( parent && parent.type() == 'object' ) {
      var path = self.path();
      return path[path.length - 1]
    }
    return undefined;
  },

  index: function() {
    var self   = this;
    var parent = self.parent();
    if ( parent && parent.type() == 'array' ) {
      var path = self.path();
      return path[path.length - 1]
    }
    return undefined;
  }
} );

exports = module.exports = { new: function(doc, path){ return new Node(doc, path); }, package: Node };

require('./doc');
