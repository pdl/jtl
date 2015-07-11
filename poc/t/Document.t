use strict;
use warnings;
use Test::More;

use JSON::JTL::Syntax::Internal qw(document);

{
  my $doc = document( { foo => [ 'bar', undef ] } );

  is (ref $doc, 'JSON::JTL::Document', 'can create a document');
  is (ref $doc->contents, 'HASH', 'can get contents');

  is ( ( ref $doc->find_value( ['foo'] ) ), 'ARRAY', 'find_value of immediate child' );
  is ( $doc->find_value( ['foo', 0 ] ), 'bar', 'find_value of grandchild' );

  can_ok( $doc, 'children' );
  my $children = $doc->children;
  is (scalar @$children, 1, 'one child');
  isa_ok($children->[0], 'JSON::JTL::Node', 'children are nodes');
  is( ref ( $children->[0]->value ), 'ARRAY', 'can get node value');

}

done_testing;
