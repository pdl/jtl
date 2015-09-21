package JSON::JTL::NodeList;
use Moo;
use JSON::JTL::Syntax::Internal qw(document throw_error);
use Scalar::Util qw(blessed);

use overload 'bool' => sub {
  my $self = shift;
  return 1 == @{$self->contents} && !! $self->contents->[0]
};

=head1 NAME

JSON::JTL::NodeList - Represent a collection of nodes

=cut

=head1 ATTRIBUTES

=head3 contents

An arrayref containing the nodes in the list.

If any members of the arrayref are nodelists, they will be replaced by their contents.

If any members of the arrayrefs are not nodes, then an error will be thrown immediately.

Warning: Adding items to the arrayref will not trigger the coercion.

=cut

has contents => (
  is => 'rw',
  default => sub { [] },
  isa => sub {
    throw_error 'ImplementationError' => "Not an ARRAY reference" unless ref $_[0] eq ref [];
    foreach my $element ( @{ $_[0] } ) {
      throw_error 'ImplementationError' => "Got undef, not Node or NodeList" unless defined $element;
      throw_error 'ImplementationError' => "Got '$element', not Node or NodeList" unless ( (ref $element) =~ /JTL::Node|JTL::Document|JTL::Scope/ );
    }
  },
  coerce  => sub {
    throw_error 'ImplementationError' => "Not an ARRAY reference" unless ref $_[0] eq ref [];
    [
       map {
        blessed $_
        ? $_->isa('JSON::JTL::NodeList')
          ? @{ $_->contents }
          : $_
        : $_
      } @{ $_[0] }
    ]
  },
);

sub map {
  my $self = shift;
  my $code = shift;
  return JSON::JTL::NodeList->new( {
    contents => [ map { $code->($_) } @{ $self->contents } ],
  } );
}

1;
