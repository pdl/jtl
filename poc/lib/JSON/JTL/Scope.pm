package JSON::JTL::Scope;
use strict;
use warnings;
use Moo;
with 'JSON::JTL::Transformer'; # yup.
use JSON::JTL::Syntax::Internal qw(nodelist);

=head1 NAME

JSON::JTL::Scope - represent a scope of execution

=cut

=head1 ATTRIBUTES

=cut

=head3 symbols

A hashref of the symbols declared in the current scope. Note that this does not inclde symbols declared in a parent or ancestor scope, even if they are accessible in the current scope.

=cut

has symbols => (
  is      => 'rw',
  default => sub { { } },
);

=head3 templates

A hashref of the template  declared in the current scope. Note that this does not inclde symbols declared in a parent or ancestor scope, even if they are accessible in the current scope.

=cut

has templates => (
  is      => 'rw',
  default => sub { [ ] },
);

=head3 current

A weak reference to the node considered to be the 'current' node in the scope.

If defined, this must be a JTL::Node, a JTL::NodeArray or a JTL::Scope.

=cut


has current => ( # the current node
  is      => 'rw',
  isweak  => 1,
  isa     => sub {
    throw_error('ImplementationError' => qq(Got "$_[0]"))
      if defined $_[0] and ((ref $_[0]) !~ /JTL::Node|JTL::Document|JTL::Scope/)
  }
);

=head3 parent

A weak reference to the parent scope, used to find accessible variables.

=cut

has parent => ( # the parent of the scope, not of the node
  is      => 'rw',
  isweak  => 1,
);

=head3 caller

A weak reference to the caller scope, used to find accessible templates for stack traces.

=cut

has caller => (
  is      => 'rw',
  isweak  => 1,
);

=head3 instruction

A reference to the current instruction

=cut

has instruction => (
  is      => 'rw',
  isweak  => 1,
);

=head3 iteration

An integer accessible to the template indicating the position in a loop.

=cut

has iteration => (
  is      => 'ro',
  default => sub { 0 },
);

=head3 subscope_iteration_index

An integer which will be used to determine the iteration of the next subscope to be created.

=cut

has subscope_iteration_index => (
  is      => 'rw',
  default => sub { 0 },
);


=head1 METHODS

=head3 subscope

  my $subscope = $self->subscope;
  my $subscope = $self->subscope( { current => $another_node } );

Creates a new scope whose parent is the current scope and returns it.

=cut

sub subscope {
  my $self = shift;
  my $args = {
    parent      => $self,
    caller      => $self,
    current     => $self->current,
    instruction => $self->instruction,
    language    => $self->language,
    ( $_[0] ? %{$_[0]} : () )
  };
  return __PACKAGE__->new( $args );
}

sub numbered_subscope {
  my $self      = shift;
  my $iteration = $self->subscope_iteration_index;
  $self->subscope_iteration_index( $iteration + 1 );
  return $self->subscope( { $_[0] ? %{ $_[0] } : () , iteration => $iteration } );
}

=head3 is_valid_symbol

  $self->is_valid_symbol('foo_123'); # true
  $self->is_valid_symbol(      {} ); # false
  $self->is_valid_symbol( '!fnord'); # false

Returns true if the symbol begins with an ASCII letter or underscore and only contains hyphens, underscores, ASCII letters, or ASCII digits.

=cut

sub is_valid_symbol {
  my $self   = shift;
  my $symbol = shift;
  return ! ref $symbol && $symbol =~ m/^[a-z_][a-z0-9_\-]*$/i;
}

=head3 get_symbol

  my $nodelist = $self->get_symbol('foo_123');

Returns the contents of the symbol with the name given if that symbol. Otherwise returns undefined.

To find the symbol, the contents of the C<symbols> attribute will be checked first; otherwise the node's parent will be queried using C<get_symbol>.

=cut

sub get_symbol {
  my $self   = shift;
  my $symbol = shift;
  $self->throw_error('ResultNodesUnexpected') unless $self->is_valid_symbol($symbol);
  return $self->symbols->{$symbol} if ( exists $self->symbols->{$symbol} );
  return $self->parent->get_symbol($symbol) if ( defined $self->parent );
  return undef;
}

=head3 declare_symbol

  $self->declare_symbol('foo_123', $nodelist);

Declares a symbol, putting it into the symbols attribute. If a symbol of the same name has already been declared in the current scope, throws an error. If a symbol of the same name exists in a parent, no error is thrown.

=cut

sub declare_symbol {
  my $self   = shift;
  my $symbol = shift;
  my $value  = shift;
  $self->throw_error('ResultNodesUnexpected') unless $self->is_valid_symbol($symbol);
  $self->throw_error('TransformationVariableDeclarationFailed' => ('Symbol alredy declared')) if ( exists $self->symbols->{$symbol} );
  $self->symbols->{$symbol} = $value;
}

sub update_symbol {
  my $self   = shift;
  my $symbol = shift;
  my $value  = nodelist(@_);
  $self->throw_error('ResultNodesUnexpected') unless $self->is_valid_symbol($symbol);
  return $self->symbols->{$symbol} = $value if ( exists $self->symbols->{$symbol} );
  return $self->parent->get_symbol($symbol) if ( defined $self->parent );
  $self->throw_error('TransformationVariableDeclarationFailed' => ('Symbol not yet declared'));
}

=head3 declare_template

  $self->declare_template($template);

Declares a template, adding it to the end of the templates list.

=cut

sub declare_template {
  my $self     = shift;
  my $template = shift;
  push @{ $self->templates }, $template;
  return $template;
}

=head3 apply_templates

  $self->apply_templates($applicator);

Progresses through the templates in the current scope in reverse order, followed by the parent scopes; at each template, executes the applicator (which must be a coderef) in scalar context with the template as the first argument. If the return value is defined, this value is returned from apply_templates immeidately and no further templates are tried.

If no templates returned a defined value, undef is returned.

=cut

sub apply_templates {
  my $self       = shift;
  my $applicator = shift // sub { $self->apply_template( shift ) };
  foreach my $template ( reverse @{ $self->templates } ) {
    my $result = $applicator->($template);
    return $result if defined $result;
  }
  return $self->caller->apply_templates($applicator) if ( defined $self->caller );
  return undef;
}


=head3 throw_error

  $self->throw_error($error_type);
  $self->throw_error($error_type, $message);

Throws a L<JSON::JTL::Error> with the type given, and optionally, a message. The scope is also passed to the error so a stack trace of the input document and the JTL document can be created, if desired.

=cut


sub throw_error {
  if ( ref $_[0] and $_[0]->isa(__PACKAGE__) ) {
    JSON::JTL::Error->new( { error_type => $_[1], message => $_[2], scope => $_[0] } )->throw;
  } else {
    JSON::JTL::Syntax::Internal::throw_error( @_ )
  }
}

=head3 enclose

  my $template = $self->enclose;
  my $template = $self->enclose( $args );

Creates a template based on the current scope, like a 'closure'.

A copy of the current symbol table and current is taken, and the instruction is also taken from C<$self>. The current node, parent node and the caller are discarded.

=cut

sub enclose {
  my $self    = shift;
  my $args    = shift;
  my $symbols = {};
  my @parent  = $self;

  while ( defined $parent[0] ) {
    my $p         = $parent[0];
    my $p_symbols = $p->symbols;

    $symbols->{$_} = $p_symbols->{$_} for keys %$p_symbols;

    @parent = $p->parent;
  }

  return __PACKAGE__->new( {
    symbols     => $symbols,
    instruction => $self->instruction,
    $args ? %$args : (),
    current     => undef,
    parent      => undef,
    caller      => undef,
  } );
}

1;
