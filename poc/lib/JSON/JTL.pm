package JSON::JTL;
use strict;
use warnings;
use JSON::JTL::Transformer;
use JSON;
use 5.010_001;
our $VERSION = '0.001';
use JSON::JTL::Syntax::Internal qw(throw_error);

=head1 NAME

JSON::JTL - Transform JSON into other JSON with more JSON

=cut

use Moo;

has transformer => (
  is      => 'rw',
  lazy    => 1,
  default => sub { JSON::JTL::Transformer->new() },
);

sub transform_data {
  my $self           = shift;
  my $source         = shift;
  my $transformation = shift;
  $self->transformer->transform( $source, $transformation );
  return map { $_->contents } @{ $result->contents };
}

sub transform_json {
  my $self                = shift;
  my $json_source         = shift;
  my $json_transformation = shift;
  my ($source, $transformation);
  eval {
    $source = JSON::decode_json($json_source);
  }; throw_error 'InputNotWellFormed', $@ if $@;
  eval {
    $source = JSON::decode_json($json_source);
  }; throw_error 'TransformationNotWellFormed', $@ if $@;
  my $result = $self->transformer->transform( $source, $transformation );
  return map { to_json $_->contents } @{ $result->contents };
}

1;
