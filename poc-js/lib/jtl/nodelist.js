var util     = require('util');
var internal = require('./internal');

var NodeList = internal.Class( {

  constructor: function(contents) {
    var self = this;
    self.contents(contents);
    self.$package().$super.call( self );
    return self;
  },

  $packageName: 'jtl/nodelist',

  contents: internal.attribute('contents', {

    coerce: function(got) {
      var self     = this;
      var contents = [];

      if ( ! util.isArray(got) ) {
        internal.throwError('InternalError', 'Contents of NodeList must be expressed in JS as an array' );
      }

      for (var i = 0; i < got.length; i++) {
        if ( got[i].isa('jtl/nodelist') ) {
          contents = contents.concat( got[i].contents() );
        } else if ( got[i].isa('jtl/node') ) {
          contents.push( got[i] );
        } else if ( got[i].isa('jtl/scope') ) {
          contents.push( got[i] );
        } else if ( got[i].isa('jtl/nodearray') ) {
          contents.push( got[i] );
        } else {
          internal.throwError('InternalError', 'Not a node, document, scope or node array')
        }
      }

      return contents;
    }

  } ),

  map: function (code) {
    var self = this;
    return internal.nodeList.new( self.contents().map( code ) );
  },

} );

exports = module.exports = { package: NodeList, new: function(contents){ return new NodeList(contents); } };

internal.nodeList = module.exports
