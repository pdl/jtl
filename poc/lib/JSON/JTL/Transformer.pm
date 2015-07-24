package JSON::JTL::Transformer;
use strict;
use warnings;
use Moo;
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

Returns a ???

=cut


sub transform {
  my ($self, $input, $transformation) = @_;
  #my $coreScope = JSON::JTL::Scope::Core->new();
  my $coreScope = JSON::JTL::Scope->new();
  my $rootScope = $coreScope->subscope( { current => document $input } );

  # Todo: this should just be an execution of the instructions.
  # It should be possible to load variables at root scope;
  foreach my $template ( grep { $_->{JTL} eq 'template' } @{ $transformation->{templates} } ) {
    $rootScope->declare_template( $template );
  }

  return $self->apply_templates($rootScope);
}

=head3 apply_templates

  $self->apply_templates( $scope );

The current scope will be used to find templates in scope and

  $self->apply_template( $scope, $template );

will be called with each.

If an undefined value is returned, the next template will be tried; if a defined value is returned, that value will be returned and no more templates will be considered.

=cut

sub apply_templates {
  my ( $self, $scope ) = @_;
  my $applicator = sub {
    $self->apply_template( $scope, shift );
  };
  return $scope->apply_templates($applicator);
}

=head3 apply_template

  $self->apply_template( $scope, $template );

Attempts to appy a single template to the scope, first using C<match_template>, returning undef if that fails; if it succeeds, returns C<process_template>.

=cut

sub apply_template {
  my ( $self, $scope, $template ) = @_;
  return $self->process_template ( $scope, $template ) if ( $self->match_template ( $scope, $template ) );
  return undef;
}

=head3 match_template

  $self->match_template( $scope, $template  );

Finds the production result of the match. If it is a single boolean true, returns true. Returns false if it is a single boolean false. Throws an error otherwise.

=cut

sub match_template {
  my ( $self, $scope, $template ) = @_;
  my $result = $self->production_result( $scope, $template->{match} );
  # todo: be sricter
  !!$result->[0];
}

=head3 process_template

  $self->process_template( $scope, $template );

=cut

sub process_template {
  my ( $self, $scope, $template, $data ) = @_;
  nodelist $self->production_result( $scope, $template->{produce} )
}

=head3 production_result

  $self->production_result( $scope, $production );

Given a production (which must be an arrayref), attempts to evaluate it. Returns the results as an arayref.

=cut

sub production_result {
  my ( $self, $parentScope, $production ) = @_;
  my $scope = $parentScope->subscope;
  my $results = [];
  foreach my $instruction ( @$production ) {
    push @$results, $self->evaluate_instruction($scope, $instruction); # should return a nodelist or undef
  }
  return $results;
}

my $instructions = {
  'apply-templates' => sub {
    my ( $self, $scope, $instruction ) = @_;
    if ( $instruction->{select} ) {
      my $selected = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'select');
      return
        $selected->map( sub {
          my $this = shift;
          $self->apply_templates(
            $scope->subscope( { current => $this } ),
          ) // die ('No template for ' . $this->type . ' ' . $this );
        } );
    }
    return $self->apply_templates( $scope );
  },
  'variable' => sub {
    my ( $self, $scope, $instruction ) = @_;
    if ( $instruction->{name} ) {
      my $name = $self->production_result( $scope, $instruction->{name} )->[-1];
      if ( $instruction->{select} ) {
        my $selected = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'select') // die;
        $scope->declare_symbol( $name, $selected );
      } else { die }
    } else { die }
    return void;
  },
  'call-variable' => sub {
    my ( $self, $scope, $instruction ) = @_;
    if ( $instruction->{name} ) {
      my $name = $self->production_result( $scope, $instruction->{name} )->[-1];
      return $@{ scope->get_symbol( $name ) };
    } else { die }
  },
  'current' => sub {
    my ( $self, $scope, $instruction ) = @_;
    $scope->current();
  },
  'name' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $name = blessed $scope->current ? $scope->current->name : undef;
    document $name;
  },
  'parent' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'select');
    if ( defined $selected ) {
      return
        $selected->map( sub {
          shift->current->parent() // ();
        } );
    }
    return $scope->current->parent() // nodelist;
  },
  'children' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'select');
    if ( defined $selected ) {
      return
        $selected->map( sub {
          my $children = shift->current->children();
          return defined $children ? @$children : ();
        } );
    }
    return nodelist $scope->current->children() // nodelist;
  },
  'for-each' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'select') // die();
    return $selected->map( sub {
        $self->evaluate_nodelist_by_attribute(
        $scope->subscope( { current => shift } ),
        $instruction,
        'produce',
      ) // die;
    } );
  },
  'literal' => sub {
    my ( $self, $scope, $instruction ) = @_;
    if ( exists $instruction->{value} ) {
      return document($instruction->{value})
    } else {
      die;
    }
  },
  'array' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $nodelist = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'select') // nodelist();
    return document [ map { $_->value } @{ $nodelist->contents } ];
  },
  'object' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $nodelist = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'select') // nodelist();
    return document { map { $_->value } @{ $nodelist->contents } };
  },
  'any' => sub {
    my ( $self, $scope, $instruction ) = @_;
    return $scope->current;
  },
  'type' => sub {
    my ( $self, $scope, $instruction ) = @_;
    return document ( $scope->current->type );
  },
  'if' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $test = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'test') // die;
    die unless 1 == @{ $test->contents };
    if ( $test->contents->[0] ) {
      return nodelist $self->evaluate_by_attribute($scope, $instruction, 'produce');
    }
    return nodelist;
  },
  'or' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $comparanda = $self->evaluate_by_attribute($scope, $instruction, 'select') // die;
    return ( ( scalar grep {!!$_} @$comparanda ) ? truth : falsehood );
  },
  'eq' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $selected = $self->evaluate_by_attribute($scope, $instruction, 'select') // [ $scope->current ];
    my $compare  = $self->evaluate_by_attribute($scope, $instruction, 'compare') // die;
    return falsehood unless 1 == @$selected;
    return falsehood unless 1 == @$compare;
    return valuesEqual(map {$_->value} @$selected, @$compare);
  },
  'same-node' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'select') // [ $scope->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute($scope, $instruction, 'compare') // die;
    return falsehood unless 1 == @{ $selected->contents };
    return falsehood unless 1 == @{ $compare->contents };
    my $comparanda = [ $selected->contents->[0], $compare->contents->[0] ];
    return truth if
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
    return falsehood;
  },
};

for my $name (keys %$instructions) {
  subname "i-$name", $instructions->{$name};
}

=head3 evaluate_instruction

  $self->evaluate_instruction( $scope, $instruction );

Given an instruction (a hashref with key JTL), evaluates the result. Throws an error if the value of JTL does not correspond to a known instruction.

=cut


sub evaluate_instruction {
  my ( $self, $scope, $instruction ) = @_;
  my $instructionName = $instruction->{JTL};
  if ( defined ( $instructions->{$instructionName} ) ) {
    return $instructions->{$instructionName}->(@_);
  }
  die("Cannot understand '$instructionName'");
}

=head3 evaluate_nodelist_by_attribute

  $self->evaluate_nodelist_by_attribute( $scope, $instruction, $attribute );

Given an instruction (a hashref with key JTL) and an attribute name, returns a nodelist with the results of the production of the cotents of that attribute.

=cut

sub evaluate_nodelist_by_attribute {
  my $self = shift;
  my $result = $self->evaluate_by_attribute(@_);
  return ( (defined $result) ? nodelist $result : $result );
}

=head3 evaluate_by_attribute

  $self->evaluate_by_attribute( $scope, $instruction, $attribute );

Given an instruction (a hashref with key JTL) and an attribute name, returns an arrayref with the results of the production of the cotents of that attribute.

=cut

sub evaluate_by_attribute {
  my ( $self, $scope, $instruction, $attribute ) = @_;
  my $nodeListContents = [];
  if ( exists $instruction->{$attribute} ) {
    return $self->production_result( $scope, $instruction->{$attribute} ); # always an arrayref
  }
  return undef;
}

1;
