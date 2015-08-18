package JSON::JTL::Error;
use strict;
use warnings;
use Moo;
with 'Throwable';

use overload '""' => sub { sprintf '[%s %s] %s', ref $_[0], $_[0]->error_type, $_[0]->message }, cmp => sub { "$_[0]" cmp "$_[1]" };

=head1 NAME

JSON::JTL::Error - represent and throw errors

=cut

=head1 SYNOPSIS

  JSON::JTL::Error->new({ error_type => 'InputNotWellFormed'})->throw;

Implements the interface from the L<Throwable> Moo role.

=cut

our $error_types = [ qw(
  ImplementationError
  ImplementationFeatureUnimplemented
  ImplementationUnknownErrorType

  InputNotWellFormed
  TransformationNotWellFormed
  TransformationInvalid
  TransformationUnexpectedType
  TransformationUnknownInstruction
  TransformationMissingRequiredAtrribute
  TransformationNoMatchingTemplate
  TransformationVariableDeclarationFailed
  ResultNodesUnexpected
  ResultNodesUnexpectedNumber
  ResultNodesNotEvenNumber
  ResultNodesMultipleNodes
  ResultNodeUnexpectedType
  ResultNodeNotBoolean
  ResultNodeNotString
) ];

=head1 ATTRIBUTES

=head3 error_type

This must be a string equal to one of the error types defined by the JTL specification.

=cut

has error_type => (
  is      => 'ro',
  default => 'ImplementationUnknownErrorType',
  isa     => sub {
    my $got = shift;
    __PACKAGE__->new->throw( { error_type => 'ImplementationUnknownErrorType' } ) unless grep { $_ eq $got } @$error_types
  },
);

=head3 message

This string provides additional information.

=cut

has message => (
  is      => 'ro',
  default => '',
);

1;
