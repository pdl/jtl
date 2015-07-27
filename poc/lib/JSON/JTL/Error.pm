package JSON::JTL::Error;
use Moo;
with 'Throwable';

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

has error_type => (
  is      => 'ro',
  default => 'ImplementationUnknownErrorType',
  isa     => sub {
    my $got = shift;
    __PACKAGE__->new->throw( { error_type => 'ImplementationUnknownErrorType' } ) unless grep { $_ eq $got } @$error_types
  },
);

1;
