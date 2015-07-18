package JSON::JTL::Node;
use Moo;
use Scalar::Util qw(looks_like_number);
use overload bool => sub {
  my $val  = $_[0]->value;
  $val && ref $val;
};
=head3 path

=cut

has path => (
  is       => 'ro',
  required => 1,
);

=head3 document

=cut

has document => (
  is       => 'ro',
  isweak   => 1,
  required => 1,
);

sub type {
  my $self = shift;
  my $val  = $self->value;
  return 'null' unless ( defined $val );
  unless ( ref $val ) {
    return 'integer' if $val =~ /^-?\d+\z/;
    return 'number' if looks_like_number($val);
    return 'string';
  }
  return 'array' if ref $val eq 'ARRAY';
  return 'object' if ref $val eq 'HASH';
  return 'boolean' if ref $val eq 'JSON::Boolean';
  return 'blessed';
}

sub value {
  my $self = shift;
  return $self->document->find_value($self->path);
}

sub parent {
  my $self = shift;
  return undef unless @{ $self->path };
  my $parent_path = [ @{ $self->path } ];
  pop @$parent_path;
  return $self->document->find_node($parent_path);
}

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

sub name {
  my $self = shift;
  return undef unless $self->parent->type eq 'object';
  return $self->path->[-1];
}

sub index {
  my $self = shift;
  return undef unless $self->parent->type eq 'array';
  return $self->path->[-1];
}

1;
