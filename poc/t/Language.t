use strict;
use warnings;
use Test::More;
use JSON::JTL::Language::WorkingDraft;

my $pkg  = 'JSON::JTL::Language::WorkingDraft';
my $lang = $pkg->new;

my $instructions = {};

my $left  = $lang->instruction_spec;
my $right = $JSON::JTL::Language::WorkingDraft::instructions;

$instructions->{$_}++ for keys %$left;
$instructions->{$_}++ for keys %$right;

foreach my $name ( keys $instructions ) {
  subtest $name => sub {
    ok( exists $left->{$name}, 'Instruction spec exists for ' . $name );
    ok( exists $right->{$name}, 'Implementaton exists for ' . $name );
  };
}

done_testing;
