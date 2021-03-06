package JSON::JTL::Error;
use strict;
use warnings;
use Moo;
with 'Throwable';
with 'StackTrace::Auto'; # Unfortunately, this builds a trace on new, not on throw. However, it's easy.

use overload '""' => sub { sprintf '[%s %s] %s'."\n".'%s', ref $_[0], $_[0]->error_type // '', $_[0]->message // '', $_[0]->stack_trace // '' }, cmp => sub { "$_[0]" cmp "$_[1]" };

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
  TransformationUnknownVariable
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
    __PACKAGE__->new( { error_type => 'ImplementationUnknownErrorType' } )->throw unless grep { $_ eq $got } @$error_types
  },
);

=head3 message

This string provides additional information.

=cut

has message => (
  is      => 'ro',
  default => '',
);

=head3 scope

This scope from which the error was called.

=cut

has scope => (
  is      => 'ro',
);

1;
