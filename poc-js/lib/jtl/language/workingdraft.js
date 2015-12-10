var internal = require('../internal');
var node     = require('../node');
var fs       = require('fs');

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
        var name     = self.evaluateNodelistByAttribute('name')   || undef;

        if ( name ) {
          if ( 1 !== name.contents().length ) {
            self.throwError('ResultNodesMultipleNodes');
          }
          name = name.contents()[0].value();
        }

        return
          selected.map( function (item) {
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

        selected.map( function (item) {
          var parent = [ item ];

          while ( ! isArray( parent[0].instruction() ) ) {
            parent = [ parent[0].parent() ];
          }

          parent[0].declareTemplate( item );

          return undefined;

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
        var node   = self.get_symbol( name ) || self.throwError('TransformationUnknownVariable');
        return internal.nodeList.new( [ node ] );
      },

      'current' : function () {
        var self = this;
        return internal.nodeList.new( [ self.current() ] );
      },

      'name' : function () {
        var self = this;
        var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        selected.map( function (item) {
          var name = item.name();
          return ( 'undefined' !== typeof(name)
            ? internal.document.new(name)
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

        selected.map( function (item) {
          var index = item.index();
          return (
            'undefined' == index
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
            ? internal.nodeList.new( [ selected.contents()[-1] ] )
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

          if ( 'number' !== valueType(index) ) {
            self.throwError('ResultNodeUnexpectedType')
          }

          if ( selected.contents().length > index ) {
            results.push( selected.contents()[index] );
          };
        } )

        return internal.nodeList.new(results);
      },
      'slice' : function () {
        var selected  = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
        var subscope  = self.subscope( { current : nodeArray [ selected ] } );
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

          if ( 'number' !== valueType(index) ) {
            self.throwError('ResultNodeUnexpectedType')
          }

          index < 0
            ? len + index
            : index;
        } ).sort();

        results = [ selected.contents().splice( from_to[0], from_to[1] ) ];

        return internal.nodelist.new (results);
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
          var children = item.children();
          return internal.nodeList.new( children );
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
    };

  },


} );

exports = module.exports = { package: Language, new: function(){ return new Language(); } };

internal.language = Language;

//   'iteration' : function () {
//     var ( self )  = @_;
//     var parent    = self.parent.parent || internal.nodeList.new( [ document 0 ] );
//     var iteration = parent.iteration;
//     internal.nodeList.new( [ document iteration ] );
//   },
//   'parent' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     return selected.map( function () {
//       shift.parent() || ();
//     } );
//   },
//   'children' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     return selected.map( function () {
//       var children = shift.children();
//       return defined children ? @children : ();
//     } );
//   },
//   'child' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var which    = self.evaluateNodelistByAttribute('name')
//       || self.evaluateNodelistByAttribute('index')
//       || self.evaluateNodelistByAttribute('which')
//       || self.throwError('TransformationMissingRequiredAttribute');
//     if ( 1 !== which.contents().length ) { self.throwError('ResultNodesUnexpectedNumber')  }
//     return selected.map( function () {
//       shift.child( which.contents()[0].value() ) || ();
//     } ) || self.throwError('ImplementationError');
//   },
//   'reverse' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     internal.nodeList.new( [ reverse @{ selected.contents() } ] );
//   },
//   'filter' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || self.throwError('TransformationMissingRequiredAtrribute');
//     return selected.map( function () {
//       var this     = shift;
//       var subScope = self.numberedSubscope( { current : this } );
//       var test     = subScope.evaluateNodelistByAttribute('test') || subScope.throwError('TransformationMissingRequiredAtrribute');
//
//       if ( 1 !== test.contents().length ) { subScope.throwError('ResultNodesMultipleNodes')  }
//       if ( ! 'boolean' eq test.contents()[0].type ) { subScope.throwError('ResultNodeNotBoolean'    )  }
//
//       if ( test.contents()[0].value() ) {
//         return subScope.evaluateNodelistByAttribute('produce') || subScope.current();
//       }
//       return ();
//     } );
//   },
//   'literal' : function () {
//     var self = this;
//     var instruction = self.instruction();
//     if ( exists instruction.value() ) {
//       return document(instruction.value())
//     } else {
//       self.throwError('TransformationMissingRequiredAtrribute');
//     }
//   },
//   'array' : function () {
//     var self = this;
//     var nodelist = self.evaluateNodelistByAttribute('select') || nodelist();
//     return internal.nodeList.new( [ document [ map { _.value() } @{ nodelist.contents() } ] ) ];
//   },
//   'object' : function () {
//     var self = this;
//     var nodelist = self.evaluateNodelistByAttribute('select') || nodelist();
//     return internal.nodeList.new( [ document { map { _.value() } @{ nodelist.contents() } } ] );
//   },
//   'if' : function () {
//     var self = this;
//     var test = self.evaluateNodelistByAttribute('test') || self.throwError('TransformationMissingRequiredAtrribute');
//     if ( 1 !== test.contents().length ) { self.throwError('ResultNodesMultipleNodes')  }
//     if ( ! 'boolean' eq test.contents()[0].type ) { self.throwError('ResultNodeNotBoolean'    )  }
//     if ( test.contents()[0] ) {
//       return self.evaluateNodelistByAttribute('produce');
//     }
//     return nodelist;
//   },
//   'count' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     return internal.nodeList.new( [ document scalar @{ selected.contents() } ] );
//   },
//   'length' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     selected.map( function () {
//       var current = shift;
//       var value   = current.value();
//       if ( ! 'string' eq valueType value ) { self.throwError('ResultNodesUnexpectedType')  }
//       return document length value;
//     } );
//   },
//   'reduce' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var length   = selected.contents().length;
//     if ( ! length >= 2 ) { self.throwError('ResultNodesUnexpectedNumber')  }
//     var current  = selected.contents()[0];
//     var last     = length - 1;
//
//     for var i ( 1..last ) {
//       var subscope = self.numberedSubscope( { current : nodeArray [ current, selected.contents()[i] ] } );
//       var l        = subscope.evaluateNodelistByAttribute('produce');
//       if ( 1 !== l.contents().length ) { self.throwError('ResultNodesMultipleNodes')  }
//       current = l.contents()[0];
//     }
//
//     return current;
//   },
//   'any' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     foreach var node (@{ selected.contents() }) {
//       var val = node.value();
//       if ( ! 'boolean' eq valueType val ) { self.throwError('ResultNodeNotBoolean')  }
//       return internal.nodeList.new( [ truth ] ) if val;
//     }
//     return internal.nodeList.new( [ falsehood ] );
//   },
//   'all' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     foreach var node (@{ selected.contents() }) {
//       var val = node.value();
//       if ( ! 'boolean' eq valueType val ) { self.throwError('ResultNodeNotBoolean')  }
//       if ( ! val ) { eturn internal.nodeList.new( [ falsehood ] )  }
//     }
//     return internal.nodeList.new( [ truth ] );
//   },
//   'zip' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var arrays   = [ grep { !!@_ } map { _.value() } @{ selected.contents() } ];
//     var extent   = max ( map { #_ } @arrays );
//     var results  = [];
//
//     if ( ! extent ) { eturn nodelist nodeArray []  }
//
//     for var i (0..extent) {
//       push @results, document [ map {
//         _[i%@_]
//       } @arrays ];
//     }
//
//     return internal.nodeList.new( [ nodeArray results ] );
//   },
//   'sameNode' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var compare  = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');
//     if ( 1 !== selected.contents().length ) { self.throwError('ResultNodesMultipleNodes')  }
//     if ( 1 !== compare.contents().length ) { self.throwError('ResultNodesMultipleNodes')  }
//     return internal.nodeList.new( [ sameNode ( selected.contents()[0] ), compare.contents()[0] ) ];
//   },
//   'union' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var test     = self.instruction().test || self.instruction()._implicit_argument; #self.instruction()_attribute('test');
//     var tester   = _tester_from_test ( test );
//
//     var @uniques = ();
//
//     foreach var node ( @{ selected.contents() } ) {
//       var subScope = self.numberedSubscope( { current : node } );
//       if ( ! any { !! _ } map { tester.( subScope, _ ) } @{[ @uniques ]} ) { ush @uniques, node  } # if this seems odd... it is. It works, but I'm not sure why it refuses to be simplified
//     }
//     return internal.nodeList.new( [ @uniques ] );
//   },
//   'intersection' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var compared = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');
//     var test     = self.instruction().test || self.instruction()._implicit_argument; #self.instruction()_attribute('test');
//     var tester   = _tester_from_test ( test );
//
//     var intersection = [];
//
//     foreach var node ( @{ selected.contents() } ) {
//       var subScope = self.numberedSubscope( { current : node } );
//       if ( any { tester.( subScope, _ ) } @{ compared.contents() } ) {
//         push @intersection, node unless any { tester.( subScope, _ ) } @intersection
//       }
//     }
//
//     return nodelist intersection;
//   },
//   'symmetricDifference' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var compared = self.evaluateNodelistByAttribute('compare') || self.throwError('TransformationMissingRequiredAtrribute');
//     var test     = self.instruction().test || self.instruction()._implicit_argument; #self.instruction()_attribute('test');
//     var tester   = _tester_from_test ( test );
//
//     var sd = [];
//
//     foreach var node (  @{ selected.contents() } ) {
//       var subScope = self.numberedSubscope( { current : node } );
//       if ( ! any { tester.( subScope, _ ) } @{ compared.contents() } ) {
//         if ( ! any { tester.( subScope, _ ) } @sd ) { ush @sd, node  }
//       }
//     }
//
//     foreach var node ( @{ compared.contents() } ) {
//       var subScope = self.numberedSubscope( { current : node } );
//       if ( ! any { tester.( subScope, _ ) } @{ selected.contents() } ) {
//         if ( ! any { tester.( subScope, _ ) } @sd ) { ush @sd, node  }
//       }
//     }
//
//     return nodelist sd;
//   },
//   'unique' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var test     = self.instruction().test || self.instruction()._implicit_argument; #self.instruction()_attribute('test');
//     var tester   = _tester_from_test ( test );
//
//     var @uniques = ();
//
//     foreach var node ( @{ selected.contents() } ) {
//       var subScope = self.numberedSubscope( { current : node } );
//       if ( ! 1 < grep { !! _ } map { tester.( subScope, _ ) } @{ selected.contents() } ) { ush @uniques, node  }
//     }
//
//     return internal.nodeList.new( [ @uniques ] );
//   },
//   'true' : function () {
//     var self = this;
//     return internal.nodeList.new( [ truth ] );
//   },
//   'false' : function () {
//     var self = this;
//     return internal.nodeList.new( [ falsehood ] );
//   },
//   'null' : function () {
//     var self = this;
//     return internal.nodeList.new( [ document undef ] );
//   },
//   'range' : function () {
//     var self = this;
//     var selected = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var compare  = self.evaluateNodelistByAttribute('end') || self.throwError('TransformationMissingRequiredAtrribute');
//
//     if ( 1 !== selected.contents().length ) { self.throwError('ResultNodesMultipleNodes')  }
//     if ( 1 !== compare.contents().length ) { self.throwError('ResultNodesMultipleNodes')  }
//
//     var start = selected.contents()[0].value();
//     var end   = compare.contents()[0].value();
//
//     if ( ! 'number' eq valueType(start) ) { self.throwError('ResultNodeUnexpectedType')  }
//     if ( ! 'number' eq valueType(end) ) { self.throwError('ResultNodeUnexpectedType')  }
//
//     if ( ! start == int start ) { self.throwError('ResultNodeUnexpectedType')  }
//     if ( ! end   == int end ) { self.throwError('ResultNodeUnexpectedType')  }
//
//     return internal.nodeList.new( [ map { document _ }
//       start > end
//       ? reverse (end..start)
//       : start..end
//     ] );
//   },
//   'add'      : function () { _arithmetic ( this, function (x, y) { x + y } ) },
//   'subtract' : function () { _arithmetic ( this, function (x, y) { x - y } ) },
//   'multiply' : function () { _arithmetic ( this, function (x, y) { x * y } ) },
//   'divide'   : function () { _arithmetic ( this, function (x, y) { x / y } ) },
//   'modulo'   : function () { _arithmetic ( this, function (x, y) { x % y } ) },
//   'power'    : function () { _arithmetic ( this, function (x, y) { x **y } ) },
//   'join'     : function () {
//     var self = this;
//     var selected  = self.evaluateNodelistByAttribute('select') || internal.nodeList.new( [ self.current() ] );
//     var delimiter = self.evaluateNodelistByAttribute('delimiter') || internal.nodeList.new( [ document '' ] );
//     var delims    = [ map { _.value() } @{ delimiter.contents() } ];
//
//     if ( ! @delims ) { self.throwError('ResultNodesUnexpectedNumber')  }
//     self.throwError('ResultNodesUnexpectedType') if grep { valueType(_) !~ /^(?:string|numeric)/ } @delims;
//     self.throwError('ResultNodesUnexpectedType') if grep { valueType(_.value()) !~ /^(?:string|numeric)/ } @{ selected.contents() };
//
//     var last = #{ selected.contents() };
//
//     var result = '';
//
//     for var i ( 0..last ) {
//       result .= selected.contents()[i].value();
//       if ( ! i == last ) { result .= delims[ i % ( 1 + #delims ) ]  }
//     }
//
//     return internal.nodeList.new( [ document result ] );
//   },
