package JSON::JTL::NodeList;
use Moo;
use JSON::JTL::Syntax::Internal qw(document);
use Scalar::Util qw(blessed);

use overload 'bool' => sub {
  my $self = shift;
  return 1 == @{$self->contents} && !! $self->contents->[0]
};

=head1 NAME

JSON::JTL::NodeList - Represent a collection of nodes

=cut

has contents => (
  is => 'rw',
  default => sub { [] },
  isa => sub {
    die "Got '$_[0]', not ARRAY reference" unless ref $_[0] eq ref [];
    foreach my $element ( @{ $_[0] } ) {
      die "Got undef, not Node or NodeList" unless defined $element;
      die "Got '$element', not Node or NodeList" unless ( (ref $element) =~ /JTL::Node|JTL::Document/ );
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

sub map {
  my $self = shift;
  my $code = shift;
  return JSON::JTL::NodeList->new( {
    contents => [ map { $code->($_) } @{ $self->contents } ],
  } );
}

sub grep {
  my $self = shift;
  my $code = shift;
  return JSON::JTL::NodeList->new( {
    contents => [ grep { $code->($_) } @{ $self->contents } ],
  } );
}

1;
