use strict;
use warnings;
use Test::More;
use Test::Deep qw(cmp_deeply);
use JSON::JTL::Scope;

my $test_suite = [
  {
    why         => 'literal returns value, irrespective of current node',
    input       => {},
    instruction => { JTL => 'literal', value => 12345 },
    output      => [ 12345 ],
  },
  {
    why         => 'literal returns deep value',
    input       => {},
    instruction => { JTL => 'literal', value => { foo => [ 12345 ] } },
    output      => [ { foo => [ 12345 ] } ],
  },
  {
    why         => 'current of empty object returns copy',
    input       => {},
    instruction => { JTL => 'current' },
    output      => [ {} ],
  },
  {
    why         => 'current of object with values returns deep copy',
    input       => { foo => { bar => 123 }  },
    instruction => { JTL => 'current' },
    output      => [ { foo => { bar => 123 } } ],
  },
  {
    why         => 'type() of JSON literals',
    input       => [ {}, [], 123, "123", JSON::true, JSON::false, undef ],
    instruction => { JTL => 'forEach', select => [ { JTL => 'children' } ], produce => [ { JTL => 'type' } ] },
    output      => [ qw( object array number string boolean boolean null ) ],
  },
  {
    why         => 'type() of JSON literals',
    input       => [ ],
    instruction => { JTL => 'forEach', select => [ { JTL => 'nodeArray' } ], produce => [ { JTL => 'type' } ] },
    output      => [ qw( nodeArray ) ],
  },
  {
    why         => '"foo" eq "foo" is true',
    input       => 'foo',
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => 'foo' } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '"foo" eq "bar" is false',
    input       => 'foo',
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => 'bar' } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '123 eq 456 is false',
    input       => 123,
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => 456 } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '"foo" eq [] is false',
    input       => 'foo',
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => [] } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '[] eq [] is true',
    input       => [],
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => [] } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '["foo"] eq [] is false',
    input       => ['foo'],
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => [] } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '["foo"] eq ["foo"] is true',
    input       => ['foo'],
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => ['foo'] } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '["foo"] eq ["bar"] is false',
    input       => ['foo'],
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => ['bar'] } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '["foo", "bar"] eq ["bar", "foo"] is false',
    input       => ['foo', 'bar'],
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => ['bar', 'foo'] } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '[] eq {} is false',
    input       => [],
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => {} } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '{} eq {} is true',
    input       => {},
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => {} } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '{foo:123} eq {foo:123} is true',
    input       => {foo=>123},
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => {foo=>123} } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '{foo:123} eq {foo:456} is false',
    input       => {foo=>123},
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => {foo=>456} } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '{foo:123} eq {bar:123} is false',
    input       => {foo=>123},
    instruction => { JTL => 'eq', compare => [ { JTL => 'literal', value => {bar=>123} } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'not true is false',
    input       => JSON::true,
    instruction => { JTL => 'not' },
    output      => [ JSON::false ],
  },
  {
    why         => 'not false is true',
    input       => JSON::false,
    instruction => { JTL => 'not' },
    output      => [ JSON::true ],
  },
  {
    why         => 'false or false is false',
    input       => JSON::false,
    instruction => { JTL => 'or', compare => [ { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'true or false is true',
    input       => JSON::true,
    instruction => { JTL => 'or', compare => [ { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'false or true is true',
    input       => JSON::false,
    instruction => { JTL => 'or', compare => [ { JTL => 'literal', value => JSON::true } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'true or true is true',
    input       => JSON::true,
    instruction => { JTL => 'or', compare => [ { JTL => 'literal', value => JSON::true } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'false xor false is false',
    input       => JSON::false,
    instruction => { JTL => 'xor', compare => [ { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'true xor false is true',
    input       => JSON::true,
    instruction => { JTL => 'xor', compare => [ { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'false xor true is true',
    input       => JSON::false,
    instruction => { JTL => 'xor', compare => [ { JTL => 'literal', value => JSON::true } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'true xor true is false',
    input       => JSON::true,
    instruction => { JTL => 'xor', compare => [ { JTL => 'literal', value => JSON::true } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'false and false is false',
    input       => JSON::false,
    instruction => { JTL => 'and', compare => [ { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'true and false is false',
    input       => JSON::true,
    instruction => { JTL => 'and', compare => [ { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'false and true is false',
    input       => JSON::false,
    instruction => { JTL => 'and', compare => [ { JTL => 'literal', value => JSON::true } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'true and true is true',
    input       => JSON::true,
    instruction => { JTL => 'and', compare => [ { JTL => 'literal', value => JSON::true } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'any(false, false) is false',
    input       => {},
    instruction => { JTL => 'any', select => [ { JTL => 'literal', value => JSON::false }, { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'any(true, false) is true',
    input       => {},
    instruction => { JTL => 'any', select => [ { JTL => 'literal', value => JSON::true }, { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'any(true, true) is true',
    input       => {},
    instruction => { JTL => 'any', select => [ { JTL => 'literal', value => JSON::true }, { JTL => 'literal', value => JSON::true } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'all(false, false) is false',
    input       => {},
    instruction => { JTL => 'all', select => [ { JTL => 'literal', value => JSON::false }, { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'all(true, false) is false',
    input       => {},
    instruction => { JTL => 'all', select => [ { JTL => 'literal', value => JSON::true }, { JTL => 'literal', value => JSON::false } ] },
    output      => [ JSON::false ],
  },
  {
    why         => 'all(true, true) is true',
    input       => {},
    instruction => { JTL => 'all', select => [ { JTL => 'literal', value => JSON::true }, { JTL => 'literal', value => JSON::true } ] },
    output      => [ JSON::true ],
  },
  {
    why         => 'true is true',
    input       => {},
    instruction => { JTL => 'true' },
    output      => [ JSON::true ],
  },
  {
    why         => 'false is false',
    input       => {},
    instruction => { JTL => 'false' },
    output      => [ JSON::false ],
  },
  {
    why         => 'null is null',
    input       => {},
    instruction => { JTL => 'null' },
    output      => [ undef ],
  },
  {
    why         => 'children works on arrays',
    input       => [ 'foo', 'bar' ],
    instruction => { JTL => 'children' },
    output      => [ 'foo', 'bar' ],
  },
  {
    why         => 'children works on objects',
    input       => { foo => 'bar' },
    instruction => { JTL => 'children' },
    output      => [ 'bar' ],
  },
  {
    why         => 'children returns empty list on strings, numbers, booleans, nulls',
    input       => [ 'abc', 123, JSON::true, undef ],
    instruction => { JTL => 'forEach', select => [ { JTL => 'children' }, ], produce => [ { JTL => 'children' } ] },
    output      => [ ],
  },
  {
    why         => 'child works on arrays',
    input       => [ 'abc', 123, JSON::true, undef ],
    instruction => { JTL => 'child', index => [ { JTL => 'literal', value => 1 }, ], },
    output      => [ 123 ],
  },
  {
    why         => 'child works on objects',
    input       => { 'foo' => 'bar', 'abc' => 123 },
    instruction => { JTL => 'child', name => [ { JTL => 'literal', value => 'abc' }, ], },
    output      => [ 123 ],
  },
  {
    why         => 'child returns empty list on strings, numbers, booleans, nulls',
    input       => [ 'abc', 123, JSON::true, undef ],
    instruction => { JTL => 'forEach', select => [ { JTL => 'child', name => [ { JTL => 'literal', value => 'abc' }, ], }, ], produce => [ { JTL => 'children' } ] },
    output      => [ ],
  },
  {
    why         => 'name returns name',
    input       => { foo => 'bar' },
    instruction => { JTL => 'forEach', select => [ { JTL => 'children' }, ], produce => [ { JTL => 'name' } ] },
    output      => [ 'foo' ],
  },
  {
    why         => 'index returns 0-based index',
    input       => [ { foo => 'bar' }, 'xyz' ],
    instruction => { JTL => 'forEach', select => [ { JTL => 'children' }, ], produce => [ { JTL => 'index' } ] },
    output      => [ 0, 1 ],
  },
  {
    why         => 'count multiple nodes',
    input       => [ { foo => 'bar' }, 'xyz' ],
    instruction => { JTL => 'count', select => [ { JTL => 'children' }, ] },
    output      => [ 2 ],
  },
  {
    why         => 'count multiple nodes, even when the same',
    input       => [ { foo => 'bar' }, 'xyz' ],
    instruction => { JTL => 'count', select => [ { JTL => 'children' }, { JTL => 'children' }, ] },
    output      => [ 4 ],
  },
  {
    why         => 'count zero nodes',
    input       => [ ],
    instruction => { JTL => 'count', select => [ { JTL => 'children' } ] },
    output      => [ 0 ],
  },
  {
    why         => 'sameNode: current vs current',
    input       => { foo => 123, bar => 123 },
    instruction => {
      JTL => 'sameNode',
      select => [
        { JTL => 'current' },
      ],
      compare => [
        { JTL => 'current' },
      ],
    },
    output      => [ JSON::true ],
  },
  {
    why         => 'sameNode: literal vs another literal (false)',
    input       => { foo => 123, bar => 123 },
    instruction => {
      JTL => 'sameNode',
      select => [
        { JTL => 'literal', value => 123 },
      ],
      compare => [
        { JTL => 'literal', value => 123 },
      ],
    },
    output      => [ JSON::false ],
  },
  {
    why         => 'In {foo:123, bar:123}, sameNode works on foo and foo',
    input       => { foo => 123, bar => 123 },
    instruction => {
      JTL => 'sameNode',
      select => [
        { JTL => 'forEach', select => [ { JTL => 'children' } ], produce => [ { JTL => 'if', test => [ { JTL => 'eq', select => [ { JTL => 'name' } ], compare => [ { JTL => 'literal', value => 'foo' } ]  } ], produce => [ { JTL => 'current' } ] } ] }
      ],
      compare => [
        { JTL => 'forEach', select => [ { JTL => 'children' } ], produce => [ { JTL => 'if', test => [ { JTL => 'eq', select => [ { JTL => 'name' } ], compare => [ { JTL => 'literal', value => 'foo' } ]  } ], produce => [ { JTL => 'current' } ] } ] }
      ],
    },
    output      => [ JSON::true ],
  },
  {
    why         => 'In {foo:123, bar:123}, sameNode on foo and bar is false (even though they are equal)',
    input       => { foo => 123, bar => 123 },
    instruction => {
      JTL => 'sameNode',
      select => [
        { JTL => 'forEach', select => [ { JTL => 'children' } ], produce => [ { JTL => 'if', test => [ { JTL => 'eq', select => [ { JTL => 'name' } ], compare => [ { JTL => 'literal', value => 'foo' } ]  } ], produce => [ { JTL => 'current' } ] } ] }
      ],
      compare => [
        { JTL => 'forEach', select => [ { JTL => 'children' } ], produce => [ { JTL => 'if', test => [ { JTL => 'eq', select => [ { JTL => 'name' } ], compare => [ { JTL => 'literal', value => 'bar' } ]  } ], produce => [ { JTL => 'current' } ] } ] }
      ],
    },
    output      => [ JSON::false ],
  },
  {
    why         => 'In {foo:123, bar:123}, sameNode on foo and current is false',
    input       => { foo => 123, bar => 123 },
    instruction => {
      JTL => 'sameNode',
      select => [
        { JTL => 'forEach', select => [ { JTL => 'children' } ], produce => [ { JTL => 'if', test => [ { JTL => 'eq', select => [ { JTL => 'name' } ], compare => [ { JTL => 'literal', value => 'foo' } ]  } ], produce => [ { JTL => 'current' } ] } ] }
      ],
      compare => [
        { JTL => 'current' }
      ],
    },
    output      => [ JSON::false ],
  },
  {
    why         => 'reverse works (multiple nodes)',
    input       => [ 123, 456, 789 ],
    instruction => {
      JTL => 'reverse',
      select => [
        { JTL => 'children' },
      ],
    },
    output      => [ 789, 456, 123 ],
  },
  {
    why         => 'reverse works (single node)',
    input       => [ 123 ],
    instruction => {
      JTL => 'reverse',
      select => [
        { JTL => 'children' },
      ],
    },
    output      => [ 123 ],
  },
  {
    why         => 'reverse works (no nodes)',
    input       => [ ],
    instruction => {
      JTL => 'reverse',
      select => [
        { JTL => 'children' },
      ],
    },
    output      => [ ],
  },
  {
    why         => 'union works',
    input       => [ 123, 456, 789 ],
    instruction => {
      JTL => 'union',
      select => [
        { JTL => 'children' },
        { JTL => 'children' },
        { JTL => 'children' },
      ],
    },
    output      => [ 123, 456, 789 ],
  },
  {
    why         => 'union tests sameNode, not valuesEqual',
    input       => [ 123, 456, 789 ],
    instruction => {
      JTL => 'union',
      select => [
        { JTL => 'children' },
        { JTL => 'literal', value => 123 },
      ],
    },
    output      => [ 123, 456, 789, 123 ],
  },
  {
    why         => 'union can apply custom test',
    input       => [ 123, 456, 789 ],
    instruction => {
      JTL => 'union',
      test => [ { JTL => 'eq', select => [ { JTL => 'child', index => [ { JTL => 'literal', value => 0 } ], } ], compare => [ { JTL => 'child', index => [ { JTL => 'literal', value => 1 } ], } ] } ],
      select => [
        { JTL => 'children' },
        { JTL => 'literal', value => 123 },
      ],
    },
    output      => [ 123, 456, 789 ],
  },
  {
    why         => 'union works on empty list too',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'union', select => [ ],  },
    output      => [ ],
  },
  {
    why         => 'intersection works',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'intersection', select => [
      { JTL => 'filter', select => [ { JTL => 'children' } ], test => [ { JTL => 'eq', compare => [ { JTL => 'literal', value => 123 } ] } ] },
      { JTL => 'filter', select => [ { JTL => 'children' } ], test => [ { JTL => 'eq', compare => [ { JTL => 'literal', value => 456 } ] } ] },
    ], compare => [
      { JTL => 'filter', select => [ { JTL => 'children' } ], test => [ { JTL => 'eq', compare => [ { JTL => 'literal', value => 456 } ] } ] },
      { JTL => 'filter', select => [ { JTL => 'children' } ], test => [ { JTL => 'eq', compare => [ { JTL => 'literal', value => 789 } ] } ] },
    ] },
    output      => [ 456 ],
  },
  {
    why         => 'intersection tests identity, not value',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'intersection', select => [ { JTL => 'literal', value => 123 } ], compare => [ { JTL => 'literal', value => 123 } ] },
    output      => [ ],
  },
  {
    why         => 'intersection can apply custom test',
    input       => [ 123, 456, 789 ],
    instruction => {
      JTL     => 'intersection',
      test    => [ { JTL => 'eq', select => [ { JTL => 'child', index => [ { JTL => 'literal', value => 0 } ], } ], compare => [ { JTL => 'child', index => [ { JTL => 'literal', value => 1 } ], } ] } ],
      select  => [ { JTL => 'children' } ],
      compare => [ { JTL => 'literal', value => 123 } ],
    },
    output => [ 123 ],
  },
  {
    why         => 'intersection works when all members match',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'intersection', select => [ { JTL => 'children' } ], compare => [ { JTL => 'children' } ] },
    output      => [ 123, 456, 789 ],
  },
  {
    why         => 'intersection works on empty lists',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'intersection', select => [ ], compare => [ ] },
    output      => [ ],
  },
  {
    why         => 'symmetricDifference works',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'symmetricDifference', select => [
      { JTL => 'filter', select => [ { JTL => 'children' } ], test => [ { JTL => 'eq', compare => [ { JTL => 'literal', value => 123 } ] } ] },
      { JTL => 'filter', select => [ { JTL => 'children' } ], test => [ { JTL => 'eq', compare => [ { JTL => 'literal', value => 456 } ] } ] },
    ], compare => [
      { JTL => 'filter', select => [ { JTL => 'children' } ], test => [ { JTL => 'eq', compare => [ { JTL => 'literal', value => 456 } ] } ] },
      { JTL => 'filter', select => [ { JTL => 'children' } ], test => [ { JTL => 'eq', compare => [ { JTL => 'literal', value => 789 } ] } ] },
    ] },
    output      => [ 123, 789 ],
  },
  {
    why         => 'symmetricDifference tests identity, not value',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'symmetricDifference', select => [ { JTL => 'literal', value => 123 } ], compare => [ { JTL => 'literal', value => 123 } ] },
    output      => [ 123, 123 ],
  },
  {
    why         => 'symmetricDifference can apply custom test',
    input       => [ 123, 456, 789 ],
    instruction => {
      JTL     => 'symmetricDifference',
      test    => [ {
          JTL     => 'eq',
          select  => [ { JTL => 'child', index => [ { JTL => 'literal', value => 0 } ] } ],
          compare => [ { JTL => 'child', index => [ { JTL => 'literal', value => 1 } ] } ]
      } ],
      select  => [ { JTL => 'children' } ],
      compare => [ { JTL => 'literal', value => 123 }, { JTL => 'literal', value => 'xyz' } ],
    },
    output => [ 456, 789, 'xyz' ],
  },
  {
    why         => 'symmetricDifference works when all members match',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'symmetricDifference', select => [ { JTL => 'children' } ], compare => [ { JTL => 'children' } ] },
    output      => [ ],
  },
  {
    why         => 'symmetricDifference works on empty lists',
    input       => [ 123, 456, 789 ],
    instruction => { JTL => 'symmetricDifference', select => [ ], compare => [ ] },
    output      => [ ],
  },
  {
    why         => 'name works',
    input       => { foo => 'bar' },
    instruction => { JTL => 'forEach', select => [ { JTL => 'children', }, ], produce => [ { JTL => 'name' } ] },
    output      => [ 'foo' ],
  },
  {
    why         => 'Can get children of NodeArray',
    input       => 123,
    instruction => { JTL => 'children', select => [ { JTL => 'nodeArray', select => [ { JTL => 'current' }, ], }, ] },
    output      => [ 123 ],
  },
  {
    why         => 'NodeArray does not molest names',
    input       => { foo => 'bar' },
    instruction => { JTL => 'forEach', select => [ { JTL => 'children', select => [ { JTL => 'nodeArray', select => [ { JTL => 'children' }, ], }, ], }, ], produce => [ { JTL => 'name' } ] },
    output      => [ 'foo' ],
  },
  {
    why         => 'Variable works',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'variable',     name => [ { JTL => 'literal', value => 'xyz' } ], select => [ { JTL => 'current' } ] },
      { JTL => 'callVariable', name => [ { JTL => 'literal', value => 'xyz' } ] },
    ],
    output      => [ { foo => 'bar' } ],
  },
  {
    why         => 'Variable executes production when declared, not when called',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'variable', name => [ { JTL => 'literal', value => 'xyz' } ], select => [ { JTL => 'current' } ] },
      { JTL => 'forEach', select => [ { JTL => 'children' } ], produce => [ { JTL => 'callVariable', name => [ { JTL => 'literal', value => 'xyz' } ] }, ], }
    ],
    output      => [ { foo => 'bar' } ],
  },
  {
    why         => 'Variable contents can be explored',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'variable', name => [ { JTL => 'literal', value => 'xyz' } ], select => [ { JTL => 'current' } ] },
      { JTL => 'children', select => [ { JTL => 'callVariable', name => [ { JTL => 'literal', value => 'xyz' } ] }, ], },
    ],
    output      => [ 'bar' ],
  },
  {
    why         => 'Variable contents retain their original membership of a document',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'variable', name => [ { JTL => 'literal', value => 'xyz' } ], select => [ { JTL => 'children' } ] },
      { JTL => 'parent', select => [ { JTL => 'callVariable', name => [ { JTL => 'literal', value => 'xyz' } ] }, ], },
    ],
    output      => [ { foo => 'bar' } ],
  },
  {
    why         => 'or must have only booleans',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'or', select => [ { JTL => 'literal', value => 1 } ], compare => [ { JTL => 'literal', value => 1 } ] },
    ],
    error => {
      error_type => 'ResultNodeNotBoolean',
    }
  },
  {
    why         => 'or must have only single booleans',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'or', select => [ { JTL => 'literal', value => JSON::true }, { JTL => 'literal', value => JSON::true } ], compare => [ { JTL => 'literal', value => JSON::false } ] },
    ],
    error => {
      error_type => 'ResultNodesMultipleNodes',
    }
  },
  # the default templates don't exist yet
  {
    why         => 'Can call applyTemplates',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'applyTemplates', select => [ { JTL => 'children' } ] },
    ],
    output => [ ], # calls applyTemplates once, finds a child; calls it again, finds nothing; returns
  },
  {
    why         => 'Can declare and use templates in the same scope',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'declareTemplates', select => [ { JTL => 'template', match => [ { JTL => 'literal', value => JSON::true } ], produce => [ { JTL => 'literal', value => 'fnord' } ] } ] },
      { JTL => 'applyTemplates' },
    ],
    output => [ 'fnord' ],
  },
  {
    why         => 'template cannot see outside variables',
    input       => { foo => 'bar' },
    instruction => [
      { JTL => 'declareTemplates', select => [ { JTL => 'template', match => [ { JTL => 'literal', value => JSON::true } ], produce => [ { JTL => 'callVariable', name => [ { JTL => 'literal', value => 'fnord' } ] } ] } ] },
      { JTL => 'variable', name => [ { JTL => 'literal', value => 'fnord' } ], select => [ { JTL => 'current' } ] },
      { JTL => 'applyTemplates' },
    ],
    error => {
      error_type => 'TransformationUnknownVariable',
    }
  },
  {
    why         => 'filter with test (one pass, one fail)',
    input       => { foo => 123, bar => 456 },
    instruction => {
      JTL => 'filter',
      select => [
        { JTL => 'children' },
      ],
      test => [
        {
          JTL => 'eq',
          compare => [ { JTL => 'literal', value => 123 } ]
        },
      ],
    },
    output => [ 123 ],
  },
  {
    why         => 'filter with test (all can fail)',
    input       => { foo => 123, bar => 456 },
    instruction => {
      JTL => 'filter',
      select => [
        { JTL => 'children' },
      ],
      test => [
        {
          JTL => 'eq',
          compare => [ { JTL => 'literal', value => 0 } ]
        },
      ],
    },
    output => [ ],
  },
];

foreach my $case (@$test_suite) {
  my $why = $case->{why};
  subtest $why => sub {
    my $transformation = {
      JTL => 'transformation',
      templates => [
        {
          JTL     => 'template',
          match   => [ { JTL => 'literal', value => JSON::true } ],
          produce => ( ( 'ARRAY' eq ref $case->{instruction} ) ? $case->{instruction} : [ $case->{instruction} ] ),
        }
      ]
    };

    my $result;

    eval {
      $result = JSON::JTL::Scope->new->transform(
        $case->{input},
        $transformation,
      );
    };

    my $error = $@;

    if ( $case->{error} ) {
        ok($error, 'This should cause an error');
        isa_ok( $error, 'JSON::JTL::Error', 'The error was JSON::JTL::Error') or return diag YAML::Dump $error;
        foreach my $key ( keys %{ $case->{error} // {} } ) {
          is_deeply ($error->$key, $case->{error}->{$key}) or return diag YAML::Dump $error;
        }
    } else {
      ok(!$error, 'This should not cause an error') or return diag $error;
      is ( scalar @{ $result->contents }, scalar @{ $case->{output} }, 'Got the expected number of return values' ) or return diag YAML::Dump $result;
      for my $i ( 0..$#{ $case->{output} } ) {
        # todo: this is a bit awkward
        cmp_deeply ( $result->contents->[$i]->value, $case->{output}->[$i], "$why ($i)" ) or diag YAML::Dump $result;
      }
    }
  }
}

use YAML;

subtest 'Full document (identity transformation)' => sub {
  my $t = '';
  $t .= $_ while <DATA>;
  my $transformation = Load ($t);

  my $original = {foo => [123, 'bar', {}]};
  my $transformed = JSON::JTL::Scope->new->transform( $original, $transformation )->contents->[0]->contents;
  cmp_deeply( $original, $transformed ) or diag Dump $transformed;
};

done_testing;

__DATA__
---
JTL: transformation
templates:
  - JTL: template
    match:
      - JTL: eq
        select:
          - JTL: type
        compare:
          - JTL: literal
            value: array
    produce:
      - JTL: array
        select:
          - JTL: applyTemplates
            select:
              - JTL: children
  - JTL: template
    match:
      - JTL: eq
        select:
          - JTL: type
        compare:
          - JTL: literal
            value: object
    produce:
      - JTL: object
        select:
          - JTL: forEach
            select:
              - JTL: children
            produce:
              - JTL: name
              - JTL: applyTemplates
  - JTL: template
    match:
      - JTL: any
        select:
          - JTL: eq
            select:
              - JTL: type
            compare:
              - JTL: literal
                value: string
          - JTL: eq
            select:
              - JTL: type
            compare:
              - JTL: literal
                value: number
          - JTL: eq
            select:
              - JTL: type
            compare:
              - JTL: literal
                value: integer
          - JTL: eq
            select:
              - JTL: type
            compare:
              - JTL: literal
                value: boolean
    produce:
      - JTL: current
