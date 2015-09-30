package JSON::JTL;
use strict;
use warnings;

use 5.010_001;
our $VERSION = '0.001';

use JSON;
use JSON::JTL::Scope;
use JSON::JTL::Syntax::Internal qw(throw_error);
use JSON::JTL::Plugins::Syntax;

=head1 NAME

JSON::JTL - Transform JSON into other JSON with more JSON

=cut

=head1 SYNOPSIS

  my $jtl = JSON->JTL->new;

  # If you have raw JSON
  my @results = $jtl->transform_json('{"foo":123}', '{"JTL":"transformation", ... });

  # If you have parsed JSON
  my @results = $jtl->transform_data( {"foo" => 123 }, $transformation );

=cut

use Moo;

=head1 METHODS

=head3 transform

  my @json_results = $jtl->transform( '{}', '{ "JTL": "transformation", ... }' );
  my @data_results = $jtl->transform(  {},   { JTL => 'transformation', ... }  );
  my @data_results = $jtl->transform(  {},  'transformation { ... }'           );

Takes a JSON string or data structure to be transformed; a JTLS string or a JSON string or a data structure of the transformation; returns a list of data structures which are the results of the transformation, or JSON strings if the original document was a JSON string.

=head3 transform_json

Takes a JSON string to be transformed, a JSON string of the transformation; returns a list of JSON strings which are the results of the transformation.

=head3 transform_data

Takes a data structure to be transformed and a data structure representing the transformation; returns a list of data structures which are the results of the transformation.

Note that transform_data does not perform any validation to check that the data structure corresponds to a valid JSON structure.

=head1 ATTRIBUTES

=head3 transformer

The object which will provide the transformation method. There is currently no need for end-users to access or change this.

=cut

has transformer => (
  is      => 'ro',
  lazy    => 1,
  default => sub { JSON::JTL::Scope->new() },
);

sub transform {
  my $self           = shift;
  my $source         = shift;
  my $transformation = shift;
  my $return_json    = 0;

  unless (ref $source) {
    eval {
      $source = JSON::decode_json($source);
      $return_json++;
    }; throw_error 'InputNotWellFormed', $@ if $@;
  }
  unless (ref $transformation) {
    if ( $transformation =~ /^\s*\{.*\}\s*$/ ) { # looks like a json object
      eval {
        $transformation = JSON::decode_json($transformation);
      }; throw_error 'TransformationNotWellFormed', $@ if $@;
    }
    else {
       eval {
        $transformation = JSON::JTL::Plugins::Syntax->new->preprocess($transformation);
      }; throw_error 'TransformationNotWellFormed', $@ if $@;
    }
  }
  my $result = $self->transformer->transform( $source, $transformation );
  return map { $return_json ? to_json $_->value, { allow_nonref => 1 } : $_->value } @{ $result->contents };

}

sub transform_data {
  my $self           = shift;
  my $source         = shift;
  my $transformation = shift;
  my $result = $self->transformer->transform( $source, $transformation );
  return map { $_->value } @{ $result->contents };
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
  return map { to_json $_->value, { allow_nonref => 1 } } @{ $result->contents };
}

=head1 SEE ALSO

=over

=item * L<JSON>

=item * L<JSON::T>

=item * L<JSON::Schema>

=item * L<XML::LibXSLT>

=back

=head1 LICENSE

This software is Copyright (C) 2015 Daniel Perrett

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

See the LICENSE file for more details.

=cut

1;
