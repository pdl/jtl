use strict;
use warnings;
use Test::More;
use JSON::JTL::Plugins::Syntax;
use YAML;# for diags

my $parser = JSON::JTL::Plugins::Syntax->new->parser;

my $tests = [
  {
    syntax => 'template{foo:bar("")}',
    means  => { 'JTL' => 'template', 'foo' => { JTL => 'bar', _implicit_argument => [''] } },
  },
  {
    syntax => 'template{foo:bar()}',
    means  => { 'JTL' => 'template', 'foo' => { JTL => 'bar', _implicit_argument => [] } },
  },
  {
    syntax => 'template{foo:bar{}}',
    means  => { 'JTL' => 'template', 'foo' => { JTL => 'bar', } },
  },
  {
    syntax => 'template{foo:"bar"}',
    means  => { 'JTL' => 'template', 'foo' => "bar" },
  },
  {
    syntax => 'template{foo:{}}',
    means  => { 'JTL' => 'template', 'foo' => {} },
  },
  {
    syntax => './foo',
    means  => { JTL => 'child', name => ['foo'] },
    what   => 'pathExpression',
  },
  {
    syntax => './0',
    means  => { JTL => 'child', index => [0] },
    what   => 'pathExpression',
  },
  {
    syntax => './*[eq{select:name(), compare:"foo"}]',
    means  => { JTL => 'filter', 'select' => [ { JTL => 'children' } ], test => [ { JTL => 'eq', select => [ { JTL => 'name' } ], 'compare' => ['foo'] } ] },
    what   => 'pathExpression',
  },
  {
    syntax => 'template{foo:./bar}',
    means  => { 'JTL' => 'template', 'foo' => { JTL => 'child', name => ['bar'] } },
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

done_testing;
