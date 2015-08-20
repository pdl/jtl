package JSON::JTL::Transformer;
use strict;
use warnings;
use Moo::Role;
use JSON::JTL::Syntax::Internal;
use JSON::JTL::Scope;
use Scalar::Util qw(blessed refaddr);
use Sub::Name qw(subname);

=head1 NAME

JSON::JTL::Transformer - perform transformations

=cut

=head1 METHODS

=head3 transform

  my @results = $self->transform($input, $transformation);

Takes an input document (which should be a parsed JSON value and not a JSON string) and a transformation, which should be a parsed object with a key JTL whose value is 'transformation'.

Returns a nodelist.

=cut


sub transform {
  my ($self, $input, $transformation) = @_;
  #my $coreScope = JSON::JTL::Scope::Core->new();
  my $rootScope = $self->subscope( { current => document $input } );

  # Todo: this should just be an execution of the instructions.
  # It should be possible to load variables at root scope;
  foreach my $template ( grep { $_->{JTL} eq 'template' } @{ $transformation->{templates} } ) {
    $rootScope->declare_template( $template );
  }

  return $rootScope->apply_templates( sub { $rootScope->apply_template( shift ) } );
}

=head3 apply_template

  $self->apply_template( $template );

Attempts to appy a single template to the scope, first using C<match_template>, returning undef if that fails; if it succeeds, returns C<process_template>.

=cut

sub apply_template {
  my ( $self, $template ) = @_;
  return $self->process_template ( $template ) if ( $self->match_template ( $template ) );
  return undef;
}

=head3 match_template

  $self->match_template( $template  );

Finds the production result of the match. If it is a single boolean true, returns true. Returns false if it is a single boolean false. Throws an error otherwise.

=cut

sub match_template {
  my ( $self, $template ) = @_;
  my $result = $self->production_result( $template->{match} );
  # todo: be sricter
  !!$result->[0];
}

=head3 process_template

  $self->process_template( $template );

=cut

sub process_template {
  my ( $self, $template, $data ) = @_;
  nodelist $self->production_result( $template->{produce} )
}

=head3 production_result

  $self->production_result( $production );

Given a production (which must be an arrayref), attempts to evaluate it. Returns the results as an arayref.

=cut

sub production_result {
  my ( $self, $production ) = @_;
  my $subScope = $self->subscope;
  my $results = [];
  foreach my $instruction ( @$production ) {
    push @$results, $subScope->evaluate_instruction($instruction); # should return a nodelist or undef
  }
  return $results;
}

my $instructions = {
  'applyTemplates' => sub {
    my ( $self, $instruction ) = @_;
    if ( $instruction->{select} ) {
      my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select');
      return
        $selected->map( sub {
          my $this = shift;
          my $subScope   = $self->subscope( { current => $this } );
          my $applicator = sub {
            $subScope->apply_template( shift );
          };
          $subScope->apply_templates(
            $applicator
          ) // throw_error TransformationNoMatchingTemplate => ('No template for ' . $this->type . ' ' . $this );
        } );
    }
    my $applicator = sub {
      $self->apply_template( shift );
    };
    return $self->apply_templates( $applicator );
  },
  'variable' => sub {
    my ( $self, $instruction ) = @_;
    my $nameNL   = $self->evaluate_nodelist_by_attribute($instruction, 'name') // throw_error 'TransformationMissingRequiredAtrribute';
    my $name     = $nameNL->contents->[0]->value;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // throw_error 'TransformationMissingRequiredAtrribute';
    $self->declare_symbol( $name, $selected );
    return void;
  },
  'callVariable' => sub {
    my ( $self, $instruction ) = @_;
    my $nameNL = $self->evaluate_nodelist_by_attribute($instruction, 'name') // throw_error 'TransformationMissingRequiredAtrribute';
    my $name   = $nameNL->contents->[0]->value;
    return nodelist [ $self->get_symbol( $name ) ];
  },
  'current' => sub {
    my ( $self, $instruction ) = @_;
    nodelist [ $self->current() ];
  },
  'name' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    nodelist [ document $selected->contents->[0]->name ];
  },
  'index' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    nodelist [ document $selected->contents->[0]->index ];
  },
  'parent' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    return $selected->map( sub {
      shift->parent() // ();
    } );
  },
  'children' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    return $selected->map( sub {
      my $children = shift->children();
      return defined $children ? @$children : ();
    } );
  },
  'forEach' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // throw_error 'TransformationMissingRequiredAtrribute';
    return $selected->map( sub {
      $self->subscope( { current => shift } )->evaluate_nodelist_by_attribute (
        $instruction,
        'produce',
      ) // throw_error 'TransformationMissingRequiredAtrribute';
    } );
  },
  'literal' => sub {
    my ( $self, $instruction ) = @_;
    if ( exists $instruction->{value} ) {
      return document($instruction->{value})
    } else {
      throw_error 'TransformationMissingRequiredAtrribute';
    }
  },
  'array' => sub {
    my ( $self, $instruction ) = @_;
    my $nodelist = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist();
    return nodelist [ document [ map { $_->value } @{ $nodelist->contents } ] ];
  },
  'object' => sub {
    my ( $self, $instruction ) = @_;
    my $nodelist = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist();
    return nodelist [ document { map { $_->value } @{ $nodelist->contents } } ];
  },
  'nodeArray' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist();
    return nodelist [ nodeArray [ @{ $selected->contents } ] ];
  },
  'type' => sub {
    my ( $self, $instruction ) = @_;
    return document ( $self->current->type );
  },
  'if' => sub {
    my ( $self, $instruction ) = @_;
    my $test = $self->evaluate_nodelist_by_attribute($instruction, 'test') // throw_error 'TransformationMissingRequiredAtrribute';
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $test->contents };
    if ( $test->contents->[0] ) {
      return $self->evaluate_nodelist_by_attribute($instruction, 'produce');
    }
    return nodelist;
  },
  'any' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    foreach my $node (@{ $selected->contents }) {
      my $val = $node->value;
      throw_error 'ResultNodeNotBoolean' unless 'boolean' eq valueType $val;
      return nodelist [ truth ] if $val;
    }
    return nodelist [ falsehood ];
  },
  'all' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    foreach my $node (@{ $selected->contents }) {
      my $val = $node->value;
      throw_error 'ResultNodeNotBoolean' unless 'boolean' eq valueType $val;
      return nodelist [ falsehood ] unless $val;
    }
    return nodelist [ truth ];
  },
  'or' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute($instruction, 'compare') // throw_error 'TransformationMissingRequiredAtrribute';
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $selected->contents };
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $compare->contents };
    throw_error 'ResultNodeNotBoolean'     unless 'boolean' eq $selected->contents->[0]->type;
    throw_error 'ResultNodeNotBoolean'     unless 'boolean' eq $compare->contents ->[0]->type;
    return nodelist [ ( $selected->contents->[0]->value || $compare->contents ->[0]->value ) ? truth : falsehood ];
  },
  'and' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute($instruction, 'compare') // throw_error 'TransformationMissingRequiredAtrribute';
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $selected->contents };
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $compare->contents };
    throw_error 'ResultNodeNotBoolean'     unless 'boolean' eq $selected->contents->[0]->type;
    throw_error 'ResultNodeNotBoolean'     unless 'boolean' eq $compare->contents ->[0]->type;
    return nodelist [ ( $selected->contents->[0]->value && $compare->contents ->[0]->value ) ? truth : falsehood ];
  },
  'eq' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute($instruction, 'compare') // throw_error 'TransformationMissingRequiredAtrribute';
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $selected->contents };
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $compare->contents };
    return nodelist [ valuesEqual( map { $_->value } map { @{ $_->contents } } $selected, $compare) ];
  },
  'sameNode' => sub {
    my ( $self, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($instruction, 'select') // [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute($instruction, 'compare') // throw_error 'TransformationMissingRequiredAtrribute';
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $selected->contents };
    throw_error 'ResultNodesMultipleNodes' unless 1 == @{ $compare->contents };
    my $comparanda = [ $selected->contents->[0], $compare->contents->[0] ];
    return nodelist [ truth ] if
      refaddr ( $comparanda->[0]->document )
      ==
      refaddr ( $comparanda->[1]->document )
      and
      @{ $comparanda->[0]->path }
      ==
      @{ $comparanda->[1]->path }
      and
      !grep {
        $comparanda->[0]->path->[$_]
        ne
        $comparanda->[1]->path->[$_]
      } 0 .. $#{ $comparanda->[0]->path };
    return nodelist [ falsehood ];
  },
};

# As a developer, I would like more meaningful stack traces than anonymous subroutines
for my $name (keys %$instructions) {
  subname "i_$name", $instructions->{$name};
}

=head3 evaluate_instruction

  $self->evaluate_instruction( $instruction );

Given an instruction (a hashref with key JTL), evaluates the result. Throws an error if the value of JTL does not correspond to a known instruction.

=cut


sub evaluate_instruction {
  my ( $self, $instruction ) = @_;
  throw_error 'TransformationUnexpectedType' => ("Not a JSON Object") unless 'HASH' eq ref $instruction;
  my $instructionName = $instruction->{JTL};
  if ( defined ( $instructions->{$instructionName} ) ) {
    return $instructions->{$instructionName}->(@_);
  }
  throw_error 'TransformationUnknownInstruction' => ("Cannot understand '$instructionName'");
}

=head3 evaluate_nodelist_by_attribute

  $self->evaluate_nodelist_by_attribute( $instruction, $attribute );

Given an instruction (a hashref with key JTL) and an attribute name, returns a nodelist with the results of the production of the cotents of that attribute.

=cut

sub evaluate_nodelist_by_attribute {
  my $self = shift;
  my $result = $self->evaluate_by_attribute(@_);
  return ( (defined $result) ? nodelist $result : $result );
}

=head3 evaluate_by_attribute

  $self->evaluate_by_attribute( $instruction, $attribute );

Given an instruction (a hashref with key JTL) and an attribute name, returns an arrayref with the results of the production of the cotents of that attribute.

=cut

sub evaluate_by_attribute {
  my ( $self, $instruction, $attribute ) = @_;
  my $nodeListContents = [];
  if ( exists $instruction->{$attribute} ) {
    return $self->production_result($instruction->{$attribute} ); # always an arrayref
  }
  return undef;
}

1;
