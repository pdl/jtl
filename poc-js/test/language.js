// Test authoring packages
var assert   = require('assert');
var chai     = require('../node_modules/chai');
var mocha    = require('../node_modules/mocha');
var fs       = require('fs');

// JTL packages

var node      = require('../lib/jtl/node');
var nodeList  = require('../lib/jtl/nodelist');
var nodeArray = require('../lib/jtl/nodearray');
var doc       = require('../lib/jtl/doc');
var scope     = require('../lib/jtl/scope');
var language  = require('../lib/jtl/language/workingdraft');

describe ('JTL Language (Working Draft)', function() {

  var instance = language.new();
  var instructionSpec = instance.instructionSpec();

  it('isa( jtl/language/workingdraft )', function() {
    chai.expect(
      instance.isa( language.package )
    ).to.be.true;
    chai.expect(
      instance.isa( 'jtl/language/workingdraft' )
    ).to.be.true;
  } );

} );

describe ('JTL Scope', function() {

  var instance = scope.new();

  it('isa( jtl/scope )', function() {
    chai.expect(
      instance.isa( scope.package )
    ).to.be.true;
    chai.expect(
      instance.isa( 'jtl/scope' )
    ).to.be.true;
  } );

  it('can transform', function() {

  var result = instance.transform( { }, {
      JTL: 'transformation',
      templates: [
        {
          JTL: 'template',
          produce: [
            {
              JTL: 'literal',
              value: 'foo'
            }
          ]
        }
      ]
    } );

    chai.expect( result.contents()[0].value() ).to.equal('foo');
  } );

  var testSuite = JSON.parse( fs.readFileSync('../poc/share/instructionTests.json') );

  describe('Conformance test:', function() {
    for ( var i = 0 ; i < testSuite.length; i++ ) {
      describe('"' + testSuite[i].why + '"', function () {
        var testCase = testSuite[i];
        var transformation = {
          JTL : 'transformation',
          templates : [
            {
              JTL     : 'template',
              match   : [ { JTL : 'literal', value : true } ],
              produce : (
                ( testCase.instruction.JTL )
                ? [ testCase.instruction ]
                : testCase.instruction
              )
            }
          ]
        };
        var result;
        var resultError;

        try {
          result = scope.new().transform( testCase.input, transformation );
        } catch ( error ) {
          resultError = error;
        };

        if ( testCase.error ) {
          it ('Should return an error', function() {
            chai.expect(resultError).to.not.be.undefined;
          } );
          it ('Should return a ' + testCase.error, function() {
            chai.expect(resultError.errorType()).to.equal(testCase.error.error_type);
          } );
        } else {
          it ('Should not return an error', function() {
            chai.expect(resultError).to.be.undefined;
          } );

          if (resultError) {
            return;
          }

          describe ('- the return value is correct', function() {

            it ('(' + testCase.output.length + ' nodes expected)', function() {
              chai.expect(
                result.contents().length
              ).to.equal(
                testCase.output.length
              );
            } );

            if ( result.contents().length !== testCase.output.length ) {
              return;
            }

            for (var j = 0; j < testCase.output.length; j++) {

              var jj = j; // because chai defers execution until after j has changed

              var makeTestFunction = function(j) {
                  return function () {
                    chai.expect(
                    result.contents()[j].value()
                  ).to.deep.equal(
                    testCase.output[j]
                  );
                }
              };

              it ('(node ' + ( jj + 1 ) + '/' + testCase.output.length + ')', makeTestFunction(jj) );
            }

          } );
        }
      } );
    }
  } );

} );
