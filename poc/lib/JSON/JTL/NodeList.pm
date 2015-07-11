package JSON::JTL::NodeList;
use Moo;
use JSON::JTL::Syntax::Internal;

has contents => (
  is => 'rw'
  default => sub { [] }
  coerce  => sub {
    map {
      blessed $_
      ? $_->isa('JSON::JTL::NodeList')
        ? @{ $_->contents }
        : $_
      : document($_)
    }
  }
);

sub map {
  my $self = shift;
  my $code = shift;
  return __PACKAGE__->new( {
    contents => [ map { $code->($_) }, @{ $self->contents } ],
  } );
}

sub grep {
  my $self = shift;
  my $code = shift;
  return __PACKAGE__->new( {
    contents => [ grep { $code->($_) }, @{ $self->contents } ],
  } );
}
