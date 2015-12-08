var util = require('util');

var internal;
exports = module.exports = internal = {

  keys: function(object) {
    var keys = [];
    for ( key in object ) {
      if ( object.hasOwnProperty(key) ) {
        keys.push(key);
      }
    }
    return keys;
  },

  sameNode: function () {
    var leftPath  = left.path();
    var rightPath = right.path();

    if (
      left.doc()
      ==
      right.doc()
      &&
      leftPath.length
      ==
      rightPath.length
      &&
      ! leftPath.filter( function ( i, value ) {
        return value !== rightPath[i];
      } ).length
    ) {
      return true;
    };

    return false;
  },

  valuesEqual: function ( left, right ) {
    var rightType = valueType(left);
    var leftType  = valueType(right);

    if (
      (
        leftType == rightType
        && (
          (
            leftType == 'boolean'
            &&
            left
            ==
            right
          ) || (
            leftType == 'string'
            &&
            left
            ==
            right
          )
        )
      ) || (
        leftType == 'number'
        &&
        rightType == 'number'
        &&
        left
        ==
        right
      )
    ){
      return true;
    };

    if (
      leftType == 'object'
      &&
      rightType == 'object'
    ) {
      if ( keys(left).length !== keys(right).length ) {
        return false;
      };
      if ( keys(left).filter(
          function ( i, key ) {
            return ( ! right.hasOwnProperty(key) || ! internal.valuesEqual ( left[key], right[key] ) )
          }
        ).length > 0 ) {
        return false;
      }
      return true;
    } else if (
      leftType == 'array'
      &&
      rightType == 'array'
    ) {
      if (left.length !== right.length){
        return false;
      };
      if ( left.filter(
          function ( i, value ) {
             return ! internal.valuesEqual ( left[i], right[i] )
           }
        ).length > 0 ) {
          return false
      }
      return true;
    }
    return false;
  },

  valueType: function(val) {
    return (
      null === val
      ? 'null'
      : util.isArray(val)
        ? 'array'
        : typeof(val)
    );
  },

  attribute: function (name, options){

    options = options || {};

    return function(val) {
      var self = this;

      if ( ! self.$attributes ) {
        self.$attributes = {};
      }

      if ( typeof (val) === 'undefined' ) {
        var returnValue = self.$attributes[name];

        if ( typeof (returnValue) === 'undefined' ) {
          if ( typeof (options.default) === 'undefined' ) {
            return returnValue;
          }
          return self.$attributes[name] = options.default();
        }
        return returnValue;
      }

      if (options.coerce) {
        val = options.coerce(val);
      }

      if (options.validate) {
        options.validate(val);
      }

      self.$attributes[name] = val;

      return self;
    };
  },

  hashMerge: function(left, right) {
    var newer = {};
    for ( key in left ) {
      newer[key] = left[key]
    }
    for ( key in right ) {
      newer[key] = right[key]
    }
    return newer;
  }
};

internal.jsface = require ('jsface');

internal.baseClass = internal.jsface.Class( {

  $package: _returnBaseClass,

  $inheritor: function(code, pkg){
    var self = this;
    pkg = pkg ? pkg : self.$package();
    return code( self, pkg,
      function(){
          return ( pkg.$super.prototype
            ? pkg.prototype.$inheritor( code, pkg.$super )
            : undefined
        );
      }
    )
  },

  $packageName: 'jtl/base',

  toString: function() {
    return '[' + this.$packageName + ']';
  },

  isa: function (what) {
    var self = this;

    if ( 'string' == typeof(what) ) {
      return self.$inheritor( function(self, pkg, next) {
        return ( what == pkg.prototype.$packageName || next()?true:false )
      } );
    } else {
      return self.$inheritor( function(self, pkg, next) {
        return ( what === pkg || next()?true:false )
      } );
    }
  },

} );

function _returnBaseClass(){ internal.baseClass }


internal.Class = function(base, attributes){
  if (!attributes) {
    attributes = base;
    base       = internal.baseClass;
  }

  if ( 'function' == typeof(attributes) ) {
    attributes = attributes(base);
  }

  return ( function _returnThisClass(){
    return internal.jsface.Class(base, internal.hashMerge( attributes, { $package: _returnThisClass } ) );
  }() );
}

var error = require('./error');
