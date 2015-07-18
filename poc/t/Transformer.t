use strict;
use warnings;
use Test::More;

use JSON::JTL::Transformer;

use YAML;
my $t = '';
$t .= $_ while <DATA>;
my $transformation = Load ($t);

diag Dump (
  JSON::JTL::Transformer->new->transform(
    {foo => [123, 'bar', {}]},
    $transformation
  )
);

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
      - JTL: type
