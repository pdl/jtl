var internal = require('./internal');
var node     = require('./node');
var util     = require('util');

var Scope = internal.Class( {

  $packageName: 'jtl/scope',

  constructor: function (args) {
    var self = this;

    if (args) {
      [
        'symbols',
        'templates',
        'current',
        'parent',
        'caller',
        'instruction',
        'iteration',
      ].map( function (name) {
        if ( args.hasOwnProperty(name) ) {
          self[name]( args[name] );
        }
      } );
    }

    self.$package().$super.call( self, self, [] );

    return self;
  },

  symbols:                internal.attribute( 'symbols',                { default: function () { return {} } } ),
  templates:              internal.attribute( 'templates',              { default: function () { return [] } } ),
  current:                internal.attribute( 'current',                { weak: true } ),
  parent:                 internal.attribute( 'parent',                 { weak: true } ),
  caller:                 internal.attribute( 'caller',                 { weak: true } ),
  instruction:            internal.attribute( 'instruction',            { weak: true } ),
  iteration:              internal.attribute( 'iteration',              { default: function () { return 0 } } ),
  language:               internal.attribute( 'language',               { default: function () { return require('./language/workingdraft').new() } } ),
  subscopeIterationIndex: internal.attribute( 'subscopeIterationIndex', { default: function () { return 0 } } ),

  subscope: function (args) {
    var self = this;
    var args = internal.hashMerge( {
      parent      : self,
      caller      : self,
      current     : self.current(),
      iteration   : self.iteration(),
      instruction : self.instruction(),
      language    : self.language(),
    }, args );
    return internal.scope.new( args );
  },

  numberedSubscope: function (args) {
    var self      = this;
    var iteration = self.subscopeIterationIndex();
    self.subscopeIterationIndex( iteration + 1 );

    return self.subscope(
      args
        ? internal.hashMerge( args, { iteration : iteration } )
        : { iteration : iteration }
    );
  },

  isValidSymbol: function (symbol) {
    return (
      'string' == typeof( symbol )
      &&
      /^[a-z_][a-z0-9_\-]*/i.matches(symbol) // duff function call
    );
  },

  getSymbol: function (symbol) {
    var self = this;

    if ( ! self.isValidSymbol(symbol) ) {
      self.throwError('ResultNodesUnexpected');
    }

    if ( self.symbols().hasOwnProperty(symbol) ) {
      return self.symbols()[symbol];
    }

    if ( 'undefined' !== typeof self.parent() ) {
      return self.parent().getSymbol(symbol);
    }

    return undefined;
  },

  declareSymbol: function ( symbol, value ) {
    var self = this;

    if ( ! self.isValidSymbol(symbol) ) {
      self.throwError('ResultNodesUnexpected')
    }

    if ( self.symbols().hasOwnProperty(symbol) ) {
      self.throwError('TransformationVariableDeclarationFailed', 'Symbol alredy declared')
    }

    return self.symbols()[symbol] = value;
  },

  updateSymbol: function ( symbol, value ) {
    var self   = this;

    value = internal.nodeList.new( [ value ] );

    if ( ! self.isValidSymbol(symbol) ) {
      self.throwError('ResultNodesUnexpected')
    }

    if ( self.symbols().hasOwnProperty(symbol) ) {
      return self.symbols()[symbol] = value
    }

    if ( 'undefined' !== typeof ( self.parent() ) ) {
      return self.parent().getSymbol(symbol);
    }

    self.throwError('TransformationVariableDeclarationFailed', 'Symbol not yet declared');
  },

  declareTemplate: function (template) {
    var self = this;
    self.templates().push(template);
    return template;
  },

  applyTemplates: function (options) {
    var self      = this;
    var options   = internal.hashMerge( { originalScope: self }, options || {} );
    var templates = self.templates();

    for ( var i = templates.length - 1; i >=0; i-- ) { // iterate backwards
      var template = templates[i];
      var result = options.originalScope.applyTemplate( template, options );

      if ( 'undefined' !== typeof result ) {
        return result;
      }
    }

    if ( 'undefined' !== typeof self.caller() ) {
      return self.caller().applyTemplates( options );
    }

    return undefined;
  },

  throwError: function ( type, message ) {
    internal.error.new( this, type, message ).throw();
  },

  enclose: function ( args ) {
    var self    = this;
    var symbols = {};
    var parent  = [ self ];

    while ( 'undefined' !== typeof parent[0] ) {
      var p        = parent[0];
      var pSymbols = p.symbols();

      for ( key in pSymbols ) {
        if ( pSymbols.hasOwnProperty(key) ) {
          symbols[key] = pSymbols[key]
        }
      }

      parent = [ p.parent() ];
    }

    return internal.scope.new(
      internal.hashMerge (
        internal.hashMerge ( {
          symbols     : symbols,
          instruction : self.instruction(),
        }, args || {} ), {
          current : undefined,
          parent  : undefined,
          caller  : undefined,
        }
      )
    );
  },

  transform: function ( input, transformation ) {
    var self = this;

    var rootScope = self.subscope( {
      current     : internal.doc.new (input),
      instruction : transformation
    } );

    var templates = rootScope.evaluateNodelistByAttribute('templates');

    if ( 'undefined' == typeof(templates) ) {
      self.throwError('TransformationMissingRequiredAtrribute');
    }

    templates.contents().map( function (item) { rootScope.declareTemplate(item) } );

    return rootScope.applyTemplates();
  },

  applyTemplate: function ( template, options ) {
    var self = this;

    var mergedScope = template.subscope( {
      caller  : self,
      current : self.current()
    } );

    if ( mergedScope.matchTemplate(options) ) {
      var result = mergedScope.evaluateNodelistByAttribute( 'produce' );

      if ( 'undefined' == typeof(result) ) {
        self.throwError ( 'TransformationMissingRequiredAtrribute' );
      }

      return result;
    }

    return undefined;
  },

  matchTemplate: function ( options ) {
    var self = this;

    options = options || {};

    // First, we check if the name of the template is the name we have been given.

    var name = self.evaluateNodelistByAttribute( 'name' ); // todo: we should really have done this at compile time

    if ( 'undefined' !== typeof(name) ) {

      var contents = name.contents();

      if ( contents.length ) {

        if ( 1 !== contents.length ) {
          self.throwError('ResultNodesMultipleNodes')
        }

        name = contents[0].value();
      } else {
        name = undefined;
      }

      if ( ! internal.valuesEqual ( name, options.name ) ) {
        return undefined;
      }

    }

    var result = self.evaluateNodelistByAttribute( 'match' );

    if ( 'undefined' == typeof(result) ) {
      return true;
    }

    if ( 1 !== result.contents().length ) {
      self.throwError('ResultNodesMultipleNodes')
    }

    if ( 'boolean' !== result.contents()[0].type() ) {
      self.throwError('ResultNodeNotBoolean')
    }

    return !!result.contents()[0];
  },

  productionResult: function (production) {
    var self = this;

    if ( ! util.isArray(production) ) {
      self.throwError( 'TransformationUnexpectedType' )
    }

    var subScope = (
      ( self.instruction() === production )
      ? self
      : self.subscope ( { instruction : production } )
    );

    var results = [];

    for ( var i = 0; i < production.length; i++ ) {
      var result = subScope.subscope ( { instruction : production[i] } ).evaluateInstruction(); // should return a nodelist or undefined

      if ( 'undefined' !== typeof (result) ) {
        results.push( result );
      }
    }

    return internal.nodeList.new(results);
  },

  evaluateInstruction: function () {
    var self        = this;
    var instruction = self.instruction() || self.throwError('InternalError', "Scope has no instruction" );

    if ( 'object' !== typeof (instruction) ) {
      self.throwError('TransformationUnexpectedType', "Not a JSON Object" );
    }

    var instructionName = instruction.JTL;

    if ( 'undefined' == typeof (instructionName) ) {
      self.throwError('TransformationUnknownInstruction', "Not a JTL instruction");
    }

    var implementation = self.language().getInstruction( instructionName );

    if ( 'undefined' !== typeof( implementation ) ) {
      try {
        var result = implementation.call(self, instruction);
      } catch ( error ) {
        if (error.isa){
          throw error;
        } else {
          self.throwError('InternalError', 'In ' + instructionName + ' got error "' + error + '"' );
        }
      }
      return result;
    }

    self.throwError('TransformationUnknownInstruction', "Cannot understand '" + instructionName + "'");
  },

  evaluateNodelistByAttribute: function (attribute) {
    var self = this;
    var nodeListContents = [];
    var instruction = self.instruction() || self.throwError('InternalError', 'This scope does not have an instruction');

    if ( instruction.hasOwnProperty('_implicit_argument') ) {
      if ( self.language().isPrimaryAttribute ( instruction[JTL], attribute ) ) {
        return self.productionResult( instruction._implicit_argument ); // always an arrayref
      }
    }

    if ( instruction.hasOwnProperty(attribute) ) {
      return self.productionResult( instruction[attribute] ); // always an arrayref
    }

    return undefined;
  },

} );

exports = module.exports = { package: Scope, new: function (args) { return new Scope(args); } };

internal.scope = module.exports;
