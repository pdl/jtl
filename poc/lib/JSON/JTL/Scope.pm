package JSON::JTL::Scope;
use strict;
use warnings;
use Moo;
use JSON::JTL::Syntax::Internal qw(nodelist);

has symbols => (
  is      => 'rw',
  default => sub { { } },
);

has templates => (
  is      => 'rw',
  default => sub { [ ] },
);

has current => ( # the current node
  is      => 'rw',
  isweak  => 1,
  isa     => sub { die qq(Got "$_[0]") unless ((ref $_[0]) =~ /JTL::Node|JTL::Document/) }
);

has parent => ( # the parent of the scope, not of the node
  is      => 'rw',
  isweak  => 1,
);

sub subscope {
  my $self = shift;
  my $args = {
    parent => $self,
    current => $self->current,
    ( $_[0] ? %{$_[0]} : () )
  };
  return __PACKAGE__->new( $args );
}

sub is_valid_symbol {
  my $self   = shift;
  my $symbol = shift;
  return ! ref $symbol && $symbol =~ m/^[a-z_][a-z0-9_\-]$/i;
}

sub get_symbol {
  my $self   = shift;
  my $symbol = shift;
  die unless $self->is_valid_symbol($symbol);
  return $self->symbols->{$symbol} if ( exists $self->symbols->{$symbol} );
  return $self->parent->get_symbol($symbol) if ( defined $self->parent );
  return undef;
}

sub declare_symbol {
  my $self   = shift;
  my $symbol = shift;
  my $value  = nodelist(@_);
  die unless $self->is_valid_symbol($symbol);
  die ('Symbol alredy declared') if ( exists $self->symbols->{$symbol} );
  $self->symbols->{$symbol} = $value;
}

sub update_symbol {
  my $self   = shift;
  my $symbol = shift;
  my $value  = nodelist(@_);
  die unless $self->is_valid_symbol($symbol);
  return $self->symbols->{$symbol} = $value if ( exists $self->symbols->{$symbol} );
  return $self->parent->get_symbol($symbol) if ( defined $self->parent );
  die ('Symbol not yet declared');
}

sub declare_template {
  my $self     = shift;
  my $template = shift;
  push @{ $self->templates }, $template;
  return $template;
}

sub apply_templates {
  my $self       = shift;
  my $applicator = shift;
  foreach my $template ( reverse @{ $self->templates } ) {
    my $result = $applicator->($template);
    return $result if defined $result;
  }
  return $self->parent->apply_templates($applicator) if ( defined $self->parent );
  return undef;
}

1;
