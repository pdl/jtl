use strict;
use warnings;
use Test::More;
use Test::Deep;

# In this test, we will be ensuring that a whole-document transformation is possible using JTL::Scope

use JSON qw(decode_json);
use JSON::JTL::Plugins::Syntax;
use JSON::JTL::Scope;
my $parser = JSON::JTL::Plugins::Syntax->new->parser;
use YAML;

my $suite;

{
  my $s = '';
  $s .= $_ while <DATA>;
  $s =~ s/\n/ /g;
  $suite = decode_json $s;
}

foreach my $case ( @$suite ) {
  my $transformation = $case->{transformation};

  my $jtl = $parser->parse( $transformation, 'jtls' );

  my $transformed = JSON::JTL::Scope->new->transform( $case->{input}, $jtl )->contents->[0]->contents;
  cmp_deeply( $transformed, $case->{output} ) or diag Dump $transformed;
}

done_testing;
__DATA__
[
  {
    "input" : [
      { "country" : "FR", "city" : "Paris" },
      { "country" : "FR", "city" : "Lyon" },
      { "country" : "FR", "city" : "Bordeaux" },
      { "country" : "FR", "city" : "Marseilles" },
      { "country" : "DE", "city" : "Berlin" },
      { "country" : "DE", "city" : "Frankfurt" },
      { "country" : "DE", "city" : "Köln" },
      { "country" : "AT", "city" : "Wien" }
    ],
    "output" : [
      { "country" : "FR", "cities" : [ "Paris", "Lyon", "Bordeaux", "Marseilles" ] },
      { "country" : "DE", "cities" : [ "Berlin", "Frankfurt", "Köln" ] },
      { "country" : "AT", "cities" : [ "Wien" ] }
    ],
    "transformation" : "
      transformation {
        templates: (
          template {
            match: type()->eq('array'),
            produce: (
              variable('cities'),
              ./*/country
                ->union { test: ./0->eq( ./1 ) }
                ->forEach(
                  variable('country'),
                  (
                    'country', $country,
                    'cities', (
                      $cities/*[ ./country->eq( $country ) ]/city
                    )->array()
                  )->object()
                )
                ->array()
            )
          }
        )
      }
    "
  }
]
