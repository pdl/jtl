package JSON::JTL::NodeArray;
use Moo;
use JSON::JTL::Syntax::Internal qw(document throw_error);
use Scalar::Util qw(blessed);

use overload 'bool' => sub {
  my $self = shift;
  return 1 == @{$self->contents} && !! $self->contents->[0]
};

=head1 NAME

JSON::JTL::NodeArray - Represent a structured, ordered collection of nodes

=cut

=head1 ATTRIBUTES

=head3 contents

An arrayref containing the nodes in the node array.

If any members of the arrayref are node lists, they will be replaced by their contents.

If any members of the arrayrefs are not nodes, then an error will be thrown immediately.

Warning: Adding items to the arrayref will not trigger the coercion.

=cut

has contents => (
  is      => 'rw',
  default => sub { [] },
  isa     => sub {
    throw_error 'ImplementationError' => "Got '$_[0]', not ARRAY reference" unless ref $_[0] eq ref [];
    foreach my $element ( @{ $_[0] } ) {
      throw_error 'ImplementationError' => "Got undef, not Node or NodeList" unless defined $element;
      throw_error 'ImplementationError' => "Got '$element', not Node or NodeList" unless ( (ref $element) =~ /JTL::Node|JTL::Document/ );
    }
  },
  coerce  => sub {
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

=head1 METHOGS

These methods are provided so that node arrays can have the same API as nodes.

=head3 children

Returns the node array's contents as an array reference.

=cut

sub children { shift->contents; }

=head3 parent

Returns C<undef>.

=cut

sub parent { undef }

=head3 name

Returns C<undef>.

=cut

sub name { undef }

=head3 index

Returns C<undef>.

=cut

sub index { undef }

=head3 type

Returns the string C<nodeArray>.

=cut

sub type { 'nodeArray' }

1;
