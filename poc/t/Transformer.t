use strict;
use warnings;
use utf8;

use Test::More;
use Test::Deep qw(cmp_deeply);
use File::ShareDir;
use JSON::JTL::Scope;
use JSON;

# In this script, we will unit-test each instruction.
#
# By default, they should complete without error and produce the expected output.
#
# Some tests include the key 'error', instead of 'output' - in which case we are expecting an error of the type specified to be thrown.

my $fn = File::ShareDir::dist_file('JSON-JTL', 'instructionTests.json');

my $test_suite_json;
open my $fh, '<', $fn or die;

while (<$fh>){
  $test_suite_json .= $_;
}

my $test_suite = JSON::decode_json($test_suite_json);

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
