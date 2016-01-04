var internal = require('../internal');
var node     = require('../node');
var util     = require('util');
var fs       = require('fs');

var _tester_from_test = function(test) {
  return ( test
    ? function(scope, alt){
        var both   = internal.nodeArray.new ( [ scope.current(), alt ] );
        var result = scope.subscope( { current: both, iteration: scope.iteration() } ).evaluateNodelistByAttribute('test');

        if ( 1 !== result.contents().length ) {
          scope.throwError('ResultNodesMultipleNodes');
        }

        if ( 'boolean' !== result.contents()[0].type() ) {
          scope.throwError('ResultNodeNotBoolean');
        }

        return result.contents()[0].value();
      }
    : function(scope, alt) {
      return internal.sameNode( scope.current(), alt );
    }
  );
};

var _arithmetic = function (self, code) {
  var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
  var compare  = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');

  if ( 1 !== compare.contents().length) {
    self.throwError('ResultNodesMultipleNodes');
  }

  var compareValue = compare.contents()[0].value();

  if ( 'number' !== internal.valueType( compareValue ) ) {
    self.throwError('ResultNodeUnexpectedType')
  }

  return selected.map( function (item) {
    var val = item.value();

    if ( 'number' !== internal.valueType(val) ) {
      self.throwError('ResultNodeUnexpectedType');
    }

    return internal.doc.new ( code( val, compareValue ) );
  } );
};


var Language = internal.Class( {

  $packageName: 'jtl/language/workingdraft',

  constructor: function() {
    var self      = this;
    self.$package().$super.call( self, self, [] );
    return self;
  },

  instructionSpec: internal.attribute( 'instructionSpec', {
    default: function () {
      var fileContents = fs.readFileSync('../poc/share/instructionSpec.json');
      return JSON.parse(fileContents);
    }
  } ),

  getInstruction: function (instructionName) {
    return this.instructions()[instructionName];
  },

  instructions: function () {
    var language = this;
    return {
      'applyTemplates' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var name     = self.evaluateNodelistByAttribute('name')   || undefined;

        if ( name ) {
          if ( 1 !== name.contents().length ) {
            self.throwError('ResultNodesMultipleNodes');
          }
          name = name.contents()[0].value();
        }

        return selected.map( function (item) {
            var subScope = self.numberedSubscope( { current : item } );
            return subScope.applyTemplates( { name : name } ) || subScope.throwError('TransformationNoMatchingTemplate');
          } );
      },

      'template' : function () {
        var self = this;
        return internal.nodeList.new( [ self.enclose() ] );
      },

      'declareTemplates' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        var parent = [ self ];

        while ( ! util.isArray( parent[0].instruction() ) ) {
          parent = [ parent[0].parent() ];
        }

        selected.map( function (item) {
          parent[0].declareTemplate( item );
        } );

        return undefined;
      },

      'variable' : function () {
        var self     = this;
        var nameNL   = self.evaluateNodelistByAttribute('name') || self.throwError('TransformationMissingRequiredAtrribute');
        var name     = nameNL.contents()[0].value();
        var selected = self.evaluateNodelistByAttribute('select')  || internal.nodeList.new( [ self.current() ] );
        self.parent().declareSymbol( name, selected );
        return undefined;
      },

      'callVariable' : function () {
        var self   = this;
        var nameNL = self.evaluateNodelistByAttribute('name') || self.throwError('TransformationMissingRequiredAtrribute');
        var name   = nameNL.contents()[0].value();
        var node   = self.getSymbol( name ) || self.throwError('TransformationUnknownVariable');
        return internal.nodeList.new( [ node ] );
      },

      'current' : function () {
        var self = this;
        return internal.nodeList.new( [ self.current() ] );
      },

      'name' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        return selected.map( function (item) {
          var name = item.name();
          return ( 'undefined' !== typeof(name)
            ? internal.doc.new(name)
            : undefined
          );
        } );
      },

      'literal' : function () {
        var self = this;
        var instruction = self.instruction();
        if ( instruction.hasOwnProperty('value') ) {
          return internal.doc.new( instruction.value )
        } else {
          self.throwError('TransformationMissingRequiredAtrribute');
        }
      },

      'index' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        return selected.map( function (item) {
          var index = item.index();
          return (
            'undefined' !== typeof ( index )
              ? internal.doc.new( index )
              : undefined
          );
        } );
      },

      'first' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select');

        return (
          selected
          ? internal.nodeList.new( [ selected.contents()[0] ] )
          : internal.nodeList.new( [ self.current() ] )
        );
      },
      'last' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select');

        return (
          selected
            ? internal.nodeList.new( [ selected.contents()[ selected.contents().length - 1 ] ] )
            : internal.nodeList.new( [ self.current() ] )
        );
      },

      'nth' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var subscope = self.subscope( { current : internal.nodeArray.new( [ selected ] ) } );
        var indexes  = self.evaluateNodelistByAttribute('which') || self.throwError('TransformationMissingAttribute');
        var results  = [];

        indexes.map( function (item) {
          var index = item.value();

          if ( 'number' !== internal.valueType(index) ) {
            self.throwError('ResultNodeUnexpectedType')
          }

          if ( selected.contents().length > index ) {
            results.push( selected.contents()[index] );
          };
        } )

        return internal.nodeList.new(results);
      },
      'slice' : function () {
        var self      = this;
        var selected  = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var from_list = self.evaluateNodelistByAttribute('from') || internal.nodeList.new( [ internal.doc.new (0) ] );
        var to_list   = self.evaluateNodelistByAttribute('to') || internal.nodeList.new( [ internal.doc.new (-1) ] );
        var results   = [];
        var len       = selected.contents().length;

        var from_to = [ from_list, to_list ].map( function (item) {
          var contents = item.contents();

          if ( 1 !== contents.length ) {
            self.throwError('ResultNodesUnexpectedNumber')
          }

          var index = contents[0].value();

          if ( 'number' !== internal.valueType(index) ) {
            self.throwError('ResultNodeUnexpectedType')
          }

          return index < 0
            ? len + index
            : index;
        } ).sort();

        results = selected.contents().splice( from_to[0], 1 + from_to[1] - from_to[0] );

        return internal.nodeList.new (results);
        //TODO:f == from
        //TODO:  ? nodelist results
        //TODO:  : internal.nodeList.new( [ reverse @results ] );
      },
      'forEach' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || self.throwError('TransformationMissingRequiredAtrribute');

        return selected.map( function (item) {
          return ( self.numberedSubscope( { current : item } ).evaluateNodelistByAttribute (
              'produce'
            ) || self.throwError('TransformationMissingRequiredAtrribute')
          );
        } );
      },
      'children' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        return selected.map( function (item) {
          var children = item.children(); // returns undefined if this is not an object/array/nodelist
          return children ? internal.nodeList.new( children ) : undefined;
        } );
      },
      'type' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        if ( 1 !== selected.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        return internal.doc.new( selected.contents()[0].type() );
      },
      'nodeArray' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ ] );

        return internal.nodeList.new( [
          internal.nodeArray.new ( selected.contents() )
        ] );
      },
      'eq' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var compare  = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');

        if ( selected.contents().length !== compare.contents().length ) {
          return internal.nodeList.new( [ internal.doc.new(false) ] )
        }

        for ( var i = 0; i < selected.contents().length; i++ ) {
          if ( ! internal.valuesEqual(
            selected.contents()[i].value(),
            compare.contents()[i].value()
          ) ) {
            return internal.nodeList.new( [ internal.doc.new(false) ] )
          }
        }
        return internal.nodeList.new( [ internal.doc.new(true) ] );
      },
      'not' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        if ( 1 !== selected.contents().length ) {
          self.throwError('ResultNodesMultipleNodes');
        }

        if ( 'boolean' !== selected.contents()[0].type() ) {
          self.throwError('ResultNodeNotBoolean')
        }

        return internal.nodeList.new( [ internal.doc.new( selected.contents()[0].value() ? false : true ) ] );
      },
      'or' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var compare  = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');

        if ( 1 !== selected.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 1 !== compare.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 'boolean' !== selected.contents()[0].type() ) {
          self.throwError('ResultNodeNotBoolean')
        }

        if ( 'boolean' !== compare.contents()[0].type() ) {
          self.throwError('ResultNodeNotBoolean')
        }

        return internal.nodeList.new( [
          internal.doc.new (
            selected.contents()[0].value() || compare.contents()[0].value()
          )
        ] );
      },
      'xor' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var compare  = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');

        if ( 1 !== selected.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 1 !== compare.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 'boolean' !== selected.contents()[0].type() ) {
          self.throwError('ResultNodeNotBoolean')
        }

        if ( 'boolean' !== compare.contents()[0].type() ) {
          self.throwError('ResultNodeNotBoolean')
        }

        return internal.nodeList.new( [
          internal.doc.new (
            selected.contents()[0].value() !== compare.contents()[0].value() // JS has no logical XOR, but since we know these are booleans, !== works just as well
          )
        ] );
      },
      'and' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var compare  = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');

        if ( 1 !== selected.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 1 !== compare.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 'boolean' !== selected.contents()[0].type() ) {
          self.throwError('ResultNodeNotBoolean')
        }

        if ( 'boolean' !== compare.contents()[0].type() ) {
          self.throwError('ResultNodeNotBoolean')
        }

        return internal.nodeList.new( [
          internal.doc.new (
            selected.contents()[0].value() && compare.contents()[0].value()
          )
        ] );
      },
      'any' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        for ( var i = 0; i < selected.contents().length; i++ ) {
          var val = selected.contents()[i].value();

          if ( 'boolean' !== internal.valueType(val) ) {
            self.throwError('ResultNodeNotBoolean')
          }

          if ( val ) {
            return internal.nodeList.new( [ internal.doc.new( true ) ] );
          }
        }

        return internal.nodeList.new( [ internal.doc.new( false ) ] );
      },
      'all' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        for ( var i = 0; i < selected.contents().length; i++ ) {
          var val = selected.contents()[i].value();

          if ( 'boolean' !== internal.valueType(val) ) {
            self.throwError('ResultNodeNotBoolean')
          }

          if ( ! val ) {
            return internal.nodeList.new( [ internal.doc.new( false ) ] );
          }
        }

        return internal.nodeList.new( [ internal.doc.new( true ) ] );
      },
      'true' : function () {
        return internal.nodeList.new( [ internal.doc.new( true ) ] );
      },
      'false' : function () {
        return internal.nodeList.new( [ internal.doc.new( false ) ] );
      },
      'null' : function () {
        return internal.nodeList.new( [ internal.doc.new( null ) ] );
      },
      'child' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var which    = self.evaluateNodelistByAttribute('name')
          || self.evaluateNodelistByAttribute('index')
          || self.evaluateNodelistByAttribute('which')
          || self.throwError('TransformationMissingRequiredAttribute');

        if ( 1 !== which.contents().length ) {
          self.throwError('ResultNodesUnexpectedNumber')
        }

        return selected.map( function (item, i) {
          return item.child( which.contents()[0].value() ) || undefined;
        } ) || self.throwError('ImplementationError');
      },
      'iteration' : function () {
        var self      = this;
        var parent    = self.parent().parent();
        var iteration = parent ? parent.iteration() : 0;
        return internal.nodeList.new( [ internal.doc.new( iteration ) ] );
      },
      'count' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        return internal.nodeList.new( [ internal.doc.new( selected.contents().length ) ] );
      },
      'sameNode' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var compare  = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');

        if ( 1 !== selected.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 1 !== compare.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        return internal.nodeList.new( [ internal.doc.new( internal.sameNode ( selected.contents()[0], compare.contents()[0] ) ) ] );
      },
      'if' : function () {
        var self = this;
        var test = self.evaluateNodelistByAttribute('test') || self.throwError('TransformationMissingRequiredAtrribute');

        if ( 1 !== test.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 'boolean' !== test.contents()[0].type() ) {
          self.throwError('ResultNodeNotBoolean')
        }

        if ( test.contents()[0].value() ) {
          return self.evaluateNodelistByAttribute('produce');
        }

        return internal.nodeList.new([]);
      },
      'reverse' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        return internal.nodeList.new( selected.contents().slice(0).reverse() );
      },
      'union' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var test     = self.instruction().test || self.instruction()._implicit_argument;
        var tester   = _tester_from_test ( test );
        var uniques = [];

        selected.map( function( node, i ) {
          var subScope = self.numberedSubscope( { current : node } );
          if ( uniques.filter ( function( item, i ) {
              return tester( subScope, item )
            } ).length == 0
          ) {
            uniques.push( node );
          }
        } );
        return internal.nodeList.new( uniques );
      },
      'intersection' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var compared = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');
        var test     = self.instruction().test || self.instruction()._implicit_argument;
        var tester   = _tester_from_test ( test );

        var intersection = [];

        selected.map( function( node, i ) {
          var subScope = self.numberedSubscope( { current : node } );

          if ( compared.contents().filter( function(item) { return tester( subScope, item ) } ).length > 0 ) {
            if ( intersection.filter( function(item) { return tester( subScope, item ) } ).length == 0 ) {
              intersection.push(node);
            }
          }

        } );

        return internal.nodeList.new( intersection );
      },
      'symmetricDifference' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var compared = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');
        var test     = self.instruction().test || self.instruction()._implicit_argument;
        var tester   = _tester_from_test ( test );

        var sd = [];

        selected.map( function( node, i ) {
          var subScope = self.numberedSubscope( { current : node } );

          if ( compared.contents().filter( function(item) { return tester( subScope, item ) } ).length == 0 ) {
            if ( sd.filter( function(item) { return tester( subScope, item ) } ).length == 0 ) {
              sd.push(node);
            }
          }
        } );

        compared.map( function( node, i ) {
          var subScope = self.numberedSubscope( { current : node } );

          if ( selected.contents().filter( function(item) { return tester( subScope, item ) } ).length == 0 ) {
            if ( sd.filter( function(item) { return tester( subScope, item ) } ).length == 0 ) {
              sd.push(node);
            }
          }
        } );

        return internal.nodeList.new( sd );
      },
      'filter' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || self.throwError('TransformationMissingRequiredAtrribute');
        return selected.map( function (item) {
          var subScope = self.numberedSubscope( { current : item } );
          var test     = subScope.evaluateNodelistByAttribute('test') || subScope.throwError('TransformationMissingRequiredAtrribute');

          if ( 1 !== test.contents().length ) {
            subScope.throwError('ResultNodesMultipleNodes')
          }
          if ( 'boolean' !== test.contents()[0].type() ) {
            subScope.throwError('ResultNodeNotBoolean')
          }

          if ( test.contents()[0].value() ) {
            return subScope.evaluateNodelistByAttribute('produce') || subScope.current();
          }

          return undefined;

        } );
      },
      'unique' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var test     = self.instruction().test || self.instruction()._implicit_argument;
        var tester   = _tester_from_test ( test );

        var uniques = [];

        selected.map( function( node, i ) {
          var subScope = self.numberedSubscope( { current : node } );
          if ( selected.contents().filter ( function( item, i ) {
              return tester( subScope, item )
            } ).length == 1
          ) {
            uniques.push( node );
          }
        } );

        return internal.nodeList.new( uniques );
      },
      'range' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var compare  = self.evaluateNodelistByAttribute('end') || self.throwError('TransformationMissingRequiredAtrribute');

        if ( 1 !== selected.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        if ( 1 !== compare.contents().length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        var start = selected.contents()[0].value();
        var end   = compare.contents()[0].value();

        if ( 'number' !== internal.valueType(start) ) {
          self.throwError('ResultNodeUnexpectedType')
        }

        if ( 'number' !== internal.valueType(end) ) {
          self.throwError('ResultNodeUnexpectedType')
        }

        if ( start !== parseInt( start ) ) {
          self.throwError('ResultNodeUnexpectedType')
        }

        if ( end !== parseInt( end ) ) {
          self.throwError('ResultNodeUnexpectedType')
        }

        return internal.nodeList.new(
          internal.range(start, end)
            .map ( function(item) { return internal.doc.new( item ) } )
        );
      },
      'parent' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        return selected.map( function (item) {
          return item.parent();
        } );
      },
      'reduce' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var length   = selected.contents().length;

        if ( length < 2 ) {
          self.throwError('ResultNodesUnexpectedNumber')
        }

        var current = selected.contents()[0];

        for ( var i = 1; i < length; i++ ) {
          var subscope = self.numberedSubscope( { current : internal.nodeArray.new( [ current, selected.contents()[i] ] ) } );
          var l        = subscope.evaluateNodelistByAttribute('produce');

          if ( 1 !== l.contents().length ) {
            self.throwError('ResultNodesMultipleNodes')
          }

          current = l.contents()[0];
        }

        return current;
      },
      'array' : function () {
        var self     = this;
        var nodelist = self.evaluateNodelistByAttribute('select') || nodelist();
        return internal.nodeList.new( [
          internal.doc.new( nodelist.contents().map(function(item){return item.value() } ) )
        ] );
      },
      'object' : function () {
        var self     = this;
        var nodelist = self.evaluateNodelistByAttribute('select') || nodelist();
        var contents = nodelist.contents();
        var o        = {};

        if ( contents.length % 2 ) {
          self.throwError('ResultNodesUnexpectedNumber')
        }

        for ( i = 0; i * 2 < contents.length; i += 2 ) {
          var k = contents[i];

          if ( 'string' !== internal.valueType(k) ) {
            self.throwError('ResultNodesUnexpectedType')
          }

          o[k] = contents[ i + 1 ];
        }

        return internal.nodeList.new( [ internal.doc.new( o ) ] );
      },
      'zip' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var arrays   = selected.contents().map(function(item) { return item.value() } ).filter( function(item) { return item.length > 0 } );
        var extent   = arrays.map(function(item) { return item.length }).reduce( function(a,b) { return a > b ? a : b }, 0 );
        var results  = [];

        if ( ! extent ) {
          return internal.nodeList.new( [ internal.nodeArray.new( [] ) ] );
        }

        for ( var i = 0; i < extent; i++ ) {
          results.push(
            internal.doc.new( arrays.map( function(item) {
              return item[ i % item.length ]
            } ) )
          );
        }

        return internal.nodeList.new( [ internal.nodeArray.new(results) ] );
      },
      'add'      : function () { return _arithmetic ( this, function (x, y) { return x + y } ) },
      'subtract' : function () { return _arithmetic ( this, function (x, y) { return x - y } ) },
      'multiply' : function () { return _arithmetic ( this, function (x, y) { return x * y } ) },
      'divide'   : function () { return _arithmetic ( this, function (x, y) { return x / y } ) },
      'modulo'   : function () { return _arithmetic ( this, function (x, y) { return x % y } ) },
      'power'    : function () { return _arithmetic ( this, Math.pow ) },

      'join'     : function () {
        var self = this;
        var selected  = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var delimiter = self.evaluateNodelistByAttribute('delimiter') || internal.nodeList.new( [ internal.doc.new('') ] );
        var delims    = delimiter.contents().map( function(item) { return item.value(); } );
        var contents  = selected.contents().map( function(item) { return item.value(); } );

        if ( 0 == delims.length ) {
          self.throwError('ResultNodesUnexpectedNumber');
        }

        if ( delims.filter( function(item) {
           var type = internal.valueType(item);
           return ( 'numeric' !== type && 'string' !== type )
        } ).length > 0 ) {
          self.throwError('ResultNodesUnexpectedType')
        }

        if ( contents.filter( function(item) {
          var type = internal.valueType(item);
          return ( 'numeric'!== type && 'string' !== type )
        } ).length > 0 ) {
          self.throwError('ResultNodesUnexpectedType')
        }

        var last = selected.contents().length - 1;

        var result = '';

        for ( var i = 0; i < contents.length; i++ ) {
          result = result + contents[i];
          if ( i !== last ) {
            result = result + delims[ i % delims.length ];
          }
        }

        return internal.nodeList.new( [ internal.doc.new( result ) ] );
      },
      'length' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        return selected.map( function (item) {
          var value   = item.value();

          if ( 'string' !== internal.valueType( value ) ) {
            self.throwError('ResultNodesUnexpectedType');
          }

          return internal.doc.new(value.length);
        } );
      },
      'while' : function () {
        var self     = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );

        var loop = function (self, loop, contents) {
          var item     = contents.shift();
          var subScope = self.numberedSubscope( { current : item } );
          var test     = subScope.evaluateNodelistByAttribute('test') || subScope.throwError('TransformationMissingRequiredAtrribute');
          var results  = [];

          if ( 1 !== test.contents().length ) {
            subScope.throwError('ResultNodesMultipleNodes');
          }

          if ( 'boolean' !== test.contents()[0].type() ) {
            subScope.throwError('ResultNodeNotBoolean');
          }

          if ( test.contents()[0].value() ) {
            var production = subScope.evaluateNodelistByAttribute('produce') || subScope.throwError('TransformationMissingRequiredAtrribute');
            contents = production.contents().concat( contents );
          } else {
            results.push(item);
          }

          if ( contents.length ) {
            results = results.concat( loop( self, loop, contents ) );
          }

          return results;
        };

        return internal.nodeList.new( loop( self, loop, selected.contents() ) );
      },

      'choose' : function () {
        var self      = this;
        var selected  = self.evaluateNodelistByAttribute('select')    || internal.nodeList.new( [ self.current() ] );
        var templates = self.evaluateNodelistByAttribute('templates') || internal.nodeList.new( [] );
        var results   = [];

        for ( var i = 0; i < selected.contents().length; i++ ) {

          var subscope = self.subscope( { current: selected.contents()[i] } );

          for ( var j = 0; j < templates.contents().length; j++ ) {

            var result = subscope.applyTemplate( templates.contents()[j], { originalScope: subscope } );

            if ( 'undefined' !== typeof result ) {
              results.push(result);
              break;
            }
          }
        }

        return internal.nodeList.new( results );
      }
    };
  },


} );

exports = module.exports = { package: Language, new: function(){ return new Language(); } };

internal.language = Language;
