package JSON::JTL::Scope;
use strict;
use warnings;
use Moo;
use JSON::JTL::Syntax::Internal qw(nodelist throw_error);

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

=cut


has current => ( # the current node
  is      => 'rw',
  isweak  => 1,
  isa     => sub { throw_error 'ImplementationError' => qq(Got "$_[0]") unless ((ref $_[0]) =~ /JTL::Node|JTL::Document/) }
);

=head3 parent

A weak reference to the parent scope, used to find accessible variables and templates.

=cut

has parent => ( # the parent of the scope, not of the node
  is      => 'rw',
  isweak  => 1,
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
    parent => $self,
    current => $self->current,
    ( $_[0] ? %{$_[0]} : () )
  };
  return __PACKAGE__->new( $args );
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
  return ! ref $symbol && $symbol =~ m/^[a-z_][a-z0-9_\-]$/i;
}

=head3 get_symbol

  my $nodelist = $self->get_symbol('foo_123');

Returns the contents of the symbol with the name given if that symol. Otherwise returns undefined.

To find the symbol, the contents of the C<symbols> attribute will be checked first; otherwise the node's parent will be queried using C<get_symbol>.

=cut

sub get_symbol {
  my $self   = shift;
  my $symbol = shift;
  throw_error 'ResultNodesUnexpected' unless $self->is_valid_symbol($symbol);
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
  my $value  = nodelist(@_);
  throw_error 'ResultNodesUnexpected' unless $self->is_valid_symbol($symbol);
  throw_error 'TransformationVariableDeclarationFailed' => ('Symbol alredy declared') if ( exists $self->symbols->{$symbol} );
  $self->symbols->{$symbol} = $value;
}

sub update_symbol {
  my $self   = shift;
  my $symbol = shift;
  my $value  = nodelist(@_);
  throw_error 'ResultNodesUnexpected' unless $self->is_valid_symbol($symbol);
  return $self->symbols->{$symbol} = $value if ( exists $self->symbols->{$symbol} );
  return $self->parent->get_symbol($symbol) if ( defined $self->parent );
  throw_error 'TransformationVariableDeclarationFailed' => ('Symbol not yet declared');
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
  my $applicator = shift;
  foreach my $template ( reverse @{ $self->templates } ) {
    my $result = $applicator->($template);
    return $result if defined $result;
  }
  return $self->parent->apply_templates($applicator) if ( defined $self->parent );
  return undef;
}

1;
