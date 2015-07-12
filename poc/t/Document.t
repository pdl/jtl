use strict;
use warnings;
use Test::More;

use JSON::JTL::Syntax::Internal qw(document);

{
  my $doc = document( { foo => [ 'bar', undef ] } );

  is (ref $doc, 'JSON::JTL::Document', 'can create a document');
  is (ref $doc->contents, 'HASH', 'can get contents');

  subtest find_value => sub {
    is ( ( ref $doc->find_value( ['foo'] ) ), 'ARRAY', 'find_value of immediate child' );
    is ( $doc->find_value( ['foo', 0 ] ), 'bar', 'find_value of grandchild' );
  };

  subtest find_node_child => sub {
    is ( ( ref $doc->find_node( ['foo'] ) ), 'JSON::JTL::Node', 'find_node of immediate child' );
    is ( $doc->find_node( ['foo'] )->path->[0], 'foo', 'its path is foo' );
    is ( scalar @{ $doc->find_node( ['foo'] )->path }, 1, 'its path is just foo' );
  };

  subtest find_node_grandchild => sub {
    is ( ( ref $doc->find_node( [ 'foo', 0 ] ) ), 'JSON::JTL::Node', 'find_node grandchild' );
    is ( $doc->find_node( [ 'foo', 0 ] )->path->[0], 'foo', 'its path begins foo' );
    is ( $doc->find_node( [ 'foo', 0 ] )->path->[1], 0, 'its path is then 0' );
    is ( scalar @{ $doc->find_node( [ 'foo', 0 ] )->path }, 2, 'its path is just foo, 0' );
  };

  subtest children => sub {
    can_ok( $doc, 'children' );
    my $children = $doc->children;
    is (scalar @$children, 1, 'one child');
    isa_ok($children->[0], 'JSON::JTL::Node', 'children are nodes');
    is( ref ( $children->[0]->value ), 'ARRAY', 'can get node value');
  };
}

done_testing;
