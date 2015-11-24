// Test authoring packages
var assert   = require('assert');
var chai     = require('../node_modules/chai');
var mocha    = require('../node_modules/mocha');

// JTL packages

var node     = require('../lib/jtl/node');
var nodeList = require('../lib/jtl/nodelist');
var doc      = require('../lib/jtl/doc');
var scope    = require('../lib/jtl/scope');
var language = require('../lib/jtl/language/workingdraft');

var hasAllMethods = function(instance, methods) {
  methods.map( function( name, i ) {
    chai.expect(instance).to.respondTo(name);
  } )
};

describe ('JTL Document', function() {
  var instance = doc.new( [ 123 ] );

  it('isa( doc.package )', function() {
    chai.expect( instance.isa( doc.package ) ).to.be.true;
    chai.expect( doc.new( [ 123 ] ).isa( 'jtl/doc' ) ).to.be.true;
    chai.expect( doc.new( [ 123 ] ).isa( 'jtl/node' ) ).to.be.true;
    chai.expect( doc.new( [ 123 ] ).isa( 'jtl/nodelist' ) ).to.be.false;
  } );

  it('isa( node.package )', function() {
    chai.expect( instance.isa( doc.package ) ).to.be.true;
  } );


  it('should have the methods we expect', function() {
    hasAllMethods (
      instance,
      [
        'doc',
        'path',
        'type',
        'value',
        'name',
        'index',
        'parent',
        'children',
        'findValue',
        'findNode'
      ]
    );
  } );

  it('should return the right result from findValue', function() {
    chai.expect(
      doc.new( { foo: [ 'bar' ] } ).findValue( [ 'foo', 0 ] )
    ).to.equal('bar');
    chai.expect(
      doc.new( { foo: [ 'bar', 'xyz' ] } ).findValue( [ 'foo', 1 ] )
    ).to.equal('xyz');
    chai.expect(
      doc.new( { foo: [ 'bar' ] } ).findValue( [ 'foo', 1 ] )
    ).to.be.undefined;
  } );

  it('should have no parent', function() {
    chai.expect( instance.parent() ).to.be.undefined;
  } );

  it('should have children', function() {
    chai.expect( instance.children() ).to.be.an( 'array' );
  } );

  it('should have a value', function() {
    chai.expect( instance.value() ).to.deep.equal( [ 123 ] );
  } );

  it('should have contents', function() {
    chai.expect( instance.contents() ).to.deep.equal( [ 123 ] );
  } );

} );

describe ('JTL Node', function() {

  it('isa( node.package )', function() {
    chai.expect( node.new( doc.new( [ 123 ] ), [0] ).isa( node.package ) ).to.be.true;
    chai.expect( node.new( doc.new( [ 123 ] ), [0] ).isa( 'jtl/node' ) ).to.be.true;
    chai.expect( node.new( doc.new( [ 123 ] ), [0] ).isa( 'jtl/nodelist' ) ).to.be.false;
  } );

  it('should have the methods we expect', function() {
    hasAllMethods (
      node.new( doc.new( [ 123 ] ), [0] ),
      [
        'doc',
        'path',
        'type',
        'value',
        'name',
        'index',
        'parent',
        'children'
      ]
    );
  } );
} );

describe ('JTL NodeList', function() {

  var instance = nodeList.new( [ doc.new( [ 123 ] ) ] );

  it('isa( nodeList.package )', function() {
    chai.expect(
      instance.isa( nodeList.package )
    ).to.be.true;
    chai.expect(
      instance.isa( 'jtl/nodelist' )
    ).to.be.true;
  } );

  it('flattens other nodelists', function() {
    chai.expect(
      nodeList.new( [
        doc.new( [ 123 ] ),
        doc.new( [ 456 ] )
      ] ).contents().length
    ).to.equal(2);
  } );

  it('flattens other nodelists', function() {
    chai.expect(
      nodeList.new( [
        nodeList.new( [
          doc.new( [ 123 ] ),
          doc.new( [ 456 ] )
        ] )
      ] ).contents().length
    ).to.equal(2);
  } );

} );

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
