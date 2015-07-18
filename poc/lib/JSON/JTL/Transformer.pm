package JSON::JTL::Transformer;
use strict;
use warnings;
use Moo;
use JSON::JTL::Syntax::Internal;
use JSON::JTL::Scope;
use Scalar::Util qw(blessed);
use Sub::Name qw(subname);

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

sub apply_templates {
  my ( $self, $scope ) = @_;
  my $applicator = sub {
    $self->apply_template( $scope, shift );
  };
  return $scope->apply_templates($applicator);
}

sub apply_template {
  my ( $self, $scope, $template ) = @_;
  return $self->process_template ( $scope, $template ) if ( $self->match_template ( $scope, $template ) );
  return undef;
}

sub match_template {
  my ( $self, $scope, $template ) = @_;
  my $result = $self->production_result( $scope, $template->{match} );
  !!$result->[0];
}

sub process_template {
  my ( $self, $scope, $template, $data ) = @_;
  nodelist $self->production_result( $scope, $template->{produce} )
}

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
  'or' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $comparanda = $self->evaluate_by_attribute($scope, $instruction, 'select') // die;
    return ( ( scalar grep {!!$_} @$comparanda ) ? truth : falsehood );
  },
  'eq' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $comparanda = $self->evaluate_by_attribute($scope, $instruction, 'select') // die;
    return falsehood unless 2 == @$comparanda;
    return truth if (
      (
        $comparanda->[0]->type eq $comparanda->[1]->type
        and (
          (
            $comparanda->[0]->type eq 'boolean'
            and
            $comparanda->[0]->value
            ==
            $comparanda->[1]->value
          ) or (
            $comparanda->[0]->type eq 'string'
            and
            $comparanda->[0]->value
            eq
            $comparanda->[1]->value
          )
        )
      ) or (
        $comparanda->[0]->type =~ /^(?:numeric|integer)$/
        and
        $comparanda->[1]->type =~ /^(?:numeric|integer)$/
        and
        $comparanda->[0]->value
        ==
        $comparanda->[1]->value
      )
    );
    return falsehood; # todo: hashes and arrays
  },
  'same-node' => sub {
    my ( $self, $scope, $instruction ) = @_;
    my $comparanda = $self->evaluate_by_attribute($scope, $instruction, 'select');
    return falsehood unless 2 == @{ $comparanda };
    return truth if
      $comparanda->[0]->document
      ==
      $comparanda->[1]->document
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

sub evaluate_instruction {
  my ( $self, $scope, $instruction ) = @_;
  my $instructionName = $instruction->{JTL};
  if ( defined ( $instructions->{$instructionName} ) ) {
    return $instructions->{$instructionName}->(@_);
  }
  die("Cannot understand '$instructionName'");
}

sub evaluate_nodelist_by_attribute {
  my $self = shift;
  my $result = $self->evaluate_by_attribute(@_);
  return ( (defined $result) ? nodelist $result : $result );
}

sub evaluate_by_attribute {
  my ( $self, $scope, $instruction, $attribute ) = @_;
  my $nodeListContents = [];
  if ( exists $instruction->{$attribute} ) {
    return $self->production_result( $scope, $instruction->{$attribute} ); # always an arrayref
  }
  return undef;
}

1;
