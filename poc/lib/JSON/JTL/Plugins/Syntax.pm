package JSON::JTL::Plugins::Syntax;
use strict;
use warnings;
use Moo;
use JSON::JTL::Plugins::Syntax::Receiver;
use Pegex::Grammar;
use Pegex::Parser;
use File::ShareDir;

has receiver => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    JSON::JTL::Plugins::Syntax::Receiver->new;
  },
);

has grammar_text => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $fn = File::ShareDir::dist_file('JSON-JTL', 'jtls.pgx');
    open my $fh, '<:encoding(UTF-8)', $fn or die qq(Could not open $fn);
    my $s = '';
    while (<$fh>) { $s .= $_ };
    $s;
  },
);

has grammar => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    Pegex::Grammar->new(
      text => $_[0]->grammar_text,
    );
  },
);

has parser => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    Pegex::Parser->new(
      grammar  => $_[0]->grammar,
      receiver => $_[0]->receiver,
    )
  },
);

sub preprocess_string {
  my $self   = shift;
  my $string = shift;
  return $self->parser->parse( $string, 'jtls' );
}

sub preprocess {
  my $self      = shift;
  my $structure = shift;
  my $ref = ref $structure;
  if (!$ref) {
    $structure = $self->preprocess_string( $structure );
  } elsif ( $ref eq 'HASH' ) {
    foreach my $key ( keys %$structure ) {
      $structure->{$key} = $self->preprocess_string( $structure->{$key} ) if ! ref $structure->{$key};
    }
  }
  return $structure;
}

1;
