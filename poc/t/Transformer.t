use strict;
use warnings;
use Test::More;
use Test::Deep qw(cmp_deeply);
use JSON::JTL::Transformer;

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
    why         => 'object type is "object"',
    input       => { foo => 123 },
    instruction => { JTL => 'type' },
    output      => [ 'object' ],
  },
  {
    why         => '"foo" eq "foo" is true',
    input       => 'foo',
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => 'foo' } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '"foo" eq "bar" is false',
    input       => 'foo',
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => 'bar' } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '"foo" eq [] is false',
    input       => 'foo',
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => [] } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '[] eq [] is true',
    input       => [],
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => [] } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '["foo"] eq [] is false',
    input       => ['foo'],
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => [] } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '["foo"] eq ["foo"] is true',
    input       => ['foo'],
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => ['foo'] } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '["foo"] eq ["bar"] is false',
    input       => ['foo'],
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => ['bar'] } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '["foo", "bar"] eq ["bar", "foo"] is false',
    input       => ['foo', 'bar'],
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => ['bar', 'foo'] } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '[] eq {} is false',
    input       => [],
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => {} } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '{} eq {} is true',
    input       => {},
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => {} } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '{foo:123} eq {foo:123} is true',
    input       => {foo=>123},
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => {foo=>123} } ] },
    output      => [ JSON::true ],
  },
  {
    why         => '{foo:123} eq {foo:456} is false',
    input       => {foo=>123},
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => {foo=>456} } ] },
    output      => [ JSON::false ],
  },
  {
    why         => '{foo:123} eq {bar:123} is false',
    input       => {foo=>123},
    instruction => { JTL => 'eq', select => [ { JTL => 'current' }, { JTL => 'literal', value => {bar=>123} } ] },
    output      => [ JSON::false ],
  },
];

foreach my $case (@$test_suite) {
  my $transformation = {
    JTL => 'transformation',
    templates => [
      {
        JTL     => 'template',
        match   => [ { JTL => 'literal', value => JSON::true } ],
        produce => [ $case->{instruction} ],
      }
    ]
  };

  my $result = JSON::JTL::Transformer->new->transform(
    $case->{input},
    $transformation,
  );

  my $why = $case->{why};

  for my $i ( 0..$#{ $case->{output} } ) {
    # todo: this is a bit awkward
    cmp_deeply ( $result->contents->[$i]->contents, $case->{output}->[$i], "$why ($i)" ) or diag YAML::Dump $result;
  }
}


use YAML;

subtest 'Full document (identity transformation)' => sub {
  my $t = '';
  $t .= $_ while <DATA>;
  my $transformation = Load ($t);

  my $original = {foo => [123, 'bar', {}]};
  my $transformed = JSON::JTL::Transformer->new->transform( $original, $transformation )->contents->[0]->contents;
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
          - JTL: literal
            value: array
    produce:
      - JTL: array
        select:
          - JTL: apply-templates
            select:
              - JTL: children
  - JTL: template
    match:
      - JTL: eq
        select:
          - JTL: type
          - JTL: literal
            value: object
    produce:
      - JTL: object
        select:
          - JTL: for-each
            select:
              - JTL: children
            produce:
              - JTL: name
              - JTL: apply-templates
  - JTL: template
    match:
      - JTL: or
        select:
          - JTL: eq
            select:
              - JTL: type
              - JTL: literal
                value: string
          - JTL: eq
            select:
              - JTL: type
              - JTL: literal
                value: number
          - JTL: eq
            select:
              - JTL: type
              - JTL: literal
                value: integer
          - JTL: eq
            select:
              - JTL: type
              - JTL: literal
                value: boolean
    produce:
      - JTL: current
