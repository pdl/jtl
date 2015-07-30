package JSON::JTL::Document;
use Moo;
extends 'JSON::JTL::Node';
use JSON::JTL::Syntax::Internal qw(throw_error);

=head1 NAME

JSON::JTL::Document - represent a JSON document (root node)

=cut

=head1 ATTRIBUTES

This class inherits attributes from L<JSON::JTL::Node>.

=head3 contents

The raw JSON value.

=cut

=head3 path

Unlike for L<JSON::JTL::Node>, this is not required in a constructor. The value defaults to (and should always be) the empty array.

=cut

has contents => (
  is => 'rw',
);

has '+path' => (
  default  => sub { [] },
  required => 0,
);

=head3 document

Unlike for L<JSON::JTL::Node>, this is not required in a constructor. The value defaults to (and should always be) the document itself.

=cut

has '+document' => (
  default  => sub { $_[0] },
  required => 0,
);


=head3 find_value

Returns the value (not the node) at a particular path from the document root. Should only be used if you know the value exists.

=cut

sub find_value {
  my $self = shift;
  my $path = shift;
  return $self->contents unless @$path;
  my @current = $self->contents; # if this is a scalar, then we risk mutating the value instead of pointing to a different value.
  for (
    my $i = 0;
    $i < @$path;
    $i++
  ) {
    my $type = ref ( $current[0] );
    if ( $type eq 'ARRAY' ) {
      @current = $current[0]->[$path->[$i]];
    } elsif ( $type eq 'HASH' ) {
      @current = $current[0]->{$path->[$i]};
    } else {
      throw_error('ImplementationError');
    }
  }
  return $current[0];
}

=head3 find_node

Returns the node (not the value) at a particular path from the document root. Should only be used if you know the value exists.

=cut

sub find_node {
  return JSON::JTL::Node->new( { document => shift, path=> shift } ); # todo: validate
}

1;
