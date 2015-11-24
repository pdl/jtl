var internal = require('./internal');
var util     = require('util');

var errorTypes = [
  'ImplementationError',
  'ImplementationFeatureUnimplemented',
  'ImplementationUnknownErrorType',

  'InputNotWellFormed',
  'TransformationNotWellFormed',
  'TransformationInvalid',
  'TransformationUnexpectedType',
  'TransformationUnknownInstruction',
  'TransformationMissingRequiredAtrribute',
  'TransformationNoMatchingTemplate',
  'TransformationVariableDeclarationFailed',
  'TransformationUnknownVariable',
  'ResultNodesUnexpected',
  'ResultNodesUnexpectedNumber',
  'ResultNodesNotEvenNumber',
  'ResultNodesMultipleNodes',
  'ResultNodeUnexpectedType',
  'ResultNodeNotBoolean',
  'ResultNodeNotString'
];

var Error = internal.Class( {

  constructor: function(args){
    var self = this;
    if (args) {
      [ 'scope', 'errorType', 'message' ].map( function(name) {
        if ( args.hasOwnProperty(name) ) {
          self[name]( args[name] );
        }
      } );
    }
    return self;
  },

  scope: internal.attribute('scope'),

  errorType: internal.attribute('errorType', {
    default: function(){ 'ImplementationError' },
    validate: function(self, value) {
      if ( ! value in errorTypes ) {
        ( new Error ( {
          errorType: 'ImplementationError',
          message: 'Unknown error type provided'
        } ) ).throw();
      }
    },
  } ),

  message: internal.attribute('message'),

  toString: function() {
    var self = this;
    return util.format ('[%s %s] %s', 'Error', self.errorType() || '', self.message() || '');
  },

  throw: function() {
    var self  = this;
    var scope = self.scope();

    if ( scope ) {
      console.log( scope );
    }

    console.trace(self.toString());

    throw self;
  }
} );


exports = module.exports = {
  package: Error,
  new: function ( scope, errorType, message ) {
    return new Error( {
      scope     : scope,
      errorType : errorType,
      message   : message
    } );
  }
};

internal.error = module.exports;

internal.throwError = function (errorType, message) {
  var error = new Error( { errorType: errorType, message: message } );
  error.throw();
};
