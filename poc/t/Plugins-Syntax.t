use strict;
use warnings;
use Test::More;
use JSON::JTL::Plugins::Syntax;
use JSON; # for true/false
use YAML; # for diags

# In this test script, we will unit-test JSON::JTL::Plugins::Syntax

my $parser = JSON::JTL::Plugins::Syntax->new->parser;

my $tests = [
  {
    syntax => 'template { foo:bar ( "" ) }',
    means  => { 'JTL' => 'template', 'foo' => [ { JTL => 'bar', _implicit_argument => [ { JTL => 'literal', value => '' } ] } ] },
  },
  {
    syntax => 'template{foo : bar( ) }',
    means  => { 'JTL' => 'template', 'foo' => [ { JTL => 'bar' } ] },
  },
  {
    syntax => 'template{foo:bar{}}',
    means  => { 'JTL' => 'template', 'foo' => [ { JTL => 'bar', } ] },
  },
  {
    syntax => 'template{foo:"bar"}',
    means  => { 'JTL' => 'template', 'foo' => [ { JTL => 'literal', value => 'bar' } ] },
  },
  {
    syntax => 'template{foo:{}}',
    means  => { 'JTL' => 'template', 'foo' => [ { JTL => 'literal', value => {} } ] },
  },
  {
    syntax => './foo',
    means  => { JTL => 'child', name => [ { JTL => 'literal', value => 'foo' } ] },
    what   => 'pathExpression',
  },
  {
    syntax => '. / 0',
    means  => { JTL => 'child', index => [ { JTL => 'literal', value => 0 }] },
    what   => 'pathExpression',
  },
  {
    syntax => './foo/bar',
    means  => { JTL => 'child', select => [ { JTL => 'child', name => [ { JTL => 'literal', value => 'foo' } ] } ], name => [ { JTL => 'literal', value => 'bar' } ] },
    what   => 'pathExpression',
  },
  {
    syntax => '. / * [ eq{ select:name(), compare:"foo" } ]',
    means  => { JTL => 'filter', 'select' => [ { JTL => 'children' } ], test => [ { JTL => 'eq', select => [ { JTL => 'name' } ], 'compare' => [ { JTL => 'literal', value => 'foo' } ] } ] },
    what   => 'pathExpression',
  },
  {
    syntax => 'template{foo:./bar}',
    means  => { 'JTL' => 'template', 'foo' => [ { JTL => 'child', name => [ { JTL => 'literal', value => 'bar' } ] } ] },
  },
  # Some tests for single-quoted and double-quoted strings
  # For some unnerving reason these need to go at the end as otherwise tests which occur after them fail
  {
    syntax => qq{" foo "},
    means  => ' foo ',
    what   => 'string',
  },
  {
    syntax => qq{' foo '},
    means  => ' foo ',
    what   => 'string',
  },
  {
    syntax => qq{"\\""},
    means  => '"',
    what   => 'string',
  },
  {
    syntax => qq{'\\''},
    means  => "'",
    what   => 'string',
  },
  {
    syntax => qq{"\\t"},
    means  => "\t",
    what   => 'string',
  },
  {
    syntax => qq{'\\t'},
    means  => "\t",
    what   => 'string',
  },
  {
    syntax => qq{"'\\"'"},
    means  => qq{'"'},
    what   => 'string',
  },
  {
    syntax => qq{'"\\'"'},
    means  => qq{"'"},
    what   => 'string',
  },
  {
    syntax => './"foo"',
    means  => { JTL => 'child', name => [ { JTL => 'literal', value => 'foo' } ] },
    what   => 'pathExpression',
  },
  {
    syntax => "./'foo'",
    means  => { JTL => 'child', name => [ { JTL => 'literal', value => 'foo' } ] },
    what   => 'pathExpression',
  },
  {
    syntax => "./foo->children()",
    means  => { JTL => 'children', select => [ { JTL => 'child', name => [ { JTL => 'literal', value => 'foo' } ] } ] },
    what   => 'instruction',
  },
  {
    syntax => "filter { select: ( ./foo, ./bar ) }",
    what   => 'instruction',
    means  => { JTL => 'filter', select => [ { JTL => 'child', name => [ { JTL => 'literal', value => 'foo' } ] }, { JTL => 'child', name => [ { JTL => 'literal', value => 'bar' }] } ] },
  },
  {
    syntax => "filter { select: ( foo() ) }",
    what   => 'instruction',
    means  => { JTL => 'filter', select => [ { JTL => 'foo' } ] },
  },
  {
    syntax => "filter { select: foo() }",
    what   => 'instruction',
    means  => { JTL => 'filter', select => [ { JTL => 'foo' } ] },
  },
  {
    syntax => "filter { select: 'foo' }",
    what   => 'instruction',
    means  => { JTL => 'filter', select => [ { JTL => 'literal', value => 'foo' } ] },
  },
  {
    syntax => "(./foo, ./bar)->filter()",
    what   => 'instruction',
    means  => { JTL => 'filter', select => [ { JTL => 'child', name => [ { JTL => 'literal', value => 'foo' } ] }, { JTL => 'child', name => [ { JTL => 'literal', value => 'bar' } ] } ] },
  },
  {
    syntax => "[1,2,3]->filter()",
    what   => 'instruction',
    means  => { JTL => 'filter', select => [ { JTL => 'literal', value => [1,2,3] } ] }
  },
  {
    syntax => "[1,2,3]->filter()->filter()",
    what   => 'instruction',
    means  => { JTL => 'filter', select => [ { JTL => 'filter', select => [ { JTL => 'literal', value => [1,2,3] } ] } ] }
  },
  {
    syntax => "true->not()",
    what   => 'instruction',
    means  => { JTL => 'not', select => [ { JTL => 'literal', value => JSON::true } ] }
  },
  {
    syntax => "parent()->name()",
    what   => 'instruction',
    means  => { JTL => 'name', select => [ { JTL => 'parent' } ] }
  },
];

foreach my $case ( @$tests ) {
  $case->{what} //= 'jtls';
  $case->{why}  //= "Parse '$case->{syntax}' as $case->{what}";
  subtest $case->{why} => sub { eval {
      my $result = $parser->parse( $case->{syntax}, $case->{what} );
      is_deeply ( $result, $case->{means}, $case->{why} ) or diag YAML::Dump $result;
    }; fail "parsing failed - $@"  if $@;
  }
}

my $complete_transformation = q`
transformation (
  template ( current() ),
  template {
    test: type()->eq('array'),
    produce: array( children() )
  },
  template {
    test: type()->eq('object'),
    produce: object (
      children()->forEach(
        name(),
        applyTemplates()
      )
    )
  }
)`;

subtest 'Can parse a complete transformation' => sub { eval {
    my $result = $parser->parse( $complete_transformation, 'jtls' );
    ok $result, 'only minimal check here for now';
  }; fail "parsing failed - $@"  if $@;
};

done_testing;
