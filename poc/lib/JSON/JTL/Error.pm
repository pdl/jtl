package JSON::JTL::Error;
use Moo;
with 'Throwable';

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

1;
