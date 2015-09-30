use strict;
use warnings;
use Test::More;

use JSON::JTL;

my $suite = [
  {
    why            => 'Transform data structures',
    input          => {"foo"=>"bar"},
    transformation => {"JTL"=>"transformation","templates"=>[{"JTL"=>"template","produce"=>[{"JTL"=>"children"}]}]},
    output         => ['bar'],
  },
  {
    why            => 'Transform JSON strings',
    input          => '{"foo":"bar"}',
    transformation => '{"JTL":"transformation","templates":[{"JTL":"template","produce":[{"JTL":"children"}]}]}',
    output         => ['"bar"'],
  },
  {
    why            => 'use JTLS',
    input          => {"foo"=>"bar"},
    transformation => 'transformation{ templates: template { produce: children() } }',
    output         => ['bar'],
  },
];

my $jtl = JSON::JTL->new;

foreach my $case ( @$suite ) {
  subtest $case->{why} => sub {
    my @results = $jtl->transform( $case->{input}, $case->{transformation} );
    is_deeply( \@results, $case->{output} );
  };
}

done_testing;
