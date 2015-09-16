package JSON::JTL::Node;
use strict;
use warnings;
use Moo;
use overload bool => sub {
  my $val  = $_[0]->value;
  $val && ref $val;
};

use JSON::JTL::Syntax::Internal qw(valueType);

=head1 NAME

JSON::JTL::Node - represent a JSON node

=head1 ATTRIBUTES

=head3 path

An arrayref of steps from the root of the document. Document nodes have an empty arrayref and their children have one element.

=cut

has path => (
  is       => 'ro',
  required => 1,
);

=head3 document

The document node to which this node belongs.

=cut

has document => (
  is       => 'ro',
  isweak   => 1,
  required => 1,
);

=head1 METHODS

=head3 type

Returns any of 'object', 'array', 'string', 'number', or 'boolean' according to the JSON type of the node's value.

=cut

sub type {
  my $self = shift;
  my $val  = $self->value;
  JSON::JTL::Syntax::Internal::valueType($val);
}

=head3 value

Returns the raw value associated with the node.

=cut

sub value {
  my $self = shift;
  return $self->document->find_value($self->path);
}

=head3 parent

Returns a node corresponding to the parent.

Returns undef if this node is the document root.

=cut

sub parent {
  my $self = shift;
  return undef unless @{ $self->path };
  my $parent_path = [ @{ $self->path } ];
  pop @$parent_path;
  return $self->document->find_node($parent_path);
}

=head3 children

Returns an arrayref containing all nodes which are values of an object or elements of an array.

Returns undef if the node is neither an object nor an array.

=cut


sub children {
  my $self = shift;
  my $type = $self->type;
  my $path = $self->path;
  if ($type eq 'array') {
    my $value = $self->value;
    return [ map { $self->document->find_node( [ @$path, $_ ] ) } 0..$#$value ]
  } elsif ($type eq 'object') {
    my $value = $self->value;
    return [ map { $self->document->find_node( [ @$path, $_ ] ) } keys %$value ]
  }
  return undef;
}

=head3 child

  my $child = $self->child(2);
  my $child = $self->child('foo');

Returns the node representing the nth child of an array node, or the named child of an object node.

=cut



sub child {
  my $self  = shift;
  my $which = shift;
  my $type  = $self->type;
  my $path  = $self->path;
  my $value = $self->value;
  if ($type eq 'array') {
    return undef unless $value->[$which];
    return $self->document->find_node( [ @$path, $which ] );
  } elsif ($type eq 'object') {
    return undef unless $value->{$which};
    return $self->document->find_node( [ @$path, $which ] );
  }
  return undef;
}

=head3 name

If the parent node is an object, returns the property name associated with this ndoe.

Otherwise returns undef.

=cut

sub name {
  my $self = shift;
  my $parent = $self->parent // return undef;
  return undef unless $parent->type eq 'object';
  return $self->path->[-1];
}


=head3 index

If the parent node is an array, returns the position this node has in the array, as a 0-based integer value.

Otherwise returns undef.

=cut

sub index {
  my $self = shift;
  my $parent = $self->parent // return undef;
  return undef unless $parent->type eq 'array';
  return $self->path->[-1];
}

1;
