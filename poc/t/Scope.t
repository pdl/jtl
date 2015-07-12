use strict;
use warnings;
use Test::More;
use JSON::JTL::Scope;

{
  my $root = JSON::JTL::Scope->new();

  is (ref $root, 'JSON::JTL::Scope', 'can create a scope');
  is (ref $root->symbols, 'HASH', 'can get symbols');
  is (ref $root->templates, 'ARRAY', 'can get templates');

  subtest subscope => sub {
    my $subscope = $root->subscope;
    is (ref $subscope, 'JSON::JTL::Scope', 'can create a subscope');
  };
}

done_testing;
