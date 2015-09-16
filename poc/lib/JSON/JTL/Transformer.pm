package JSON::JTL::Transformer;
use strict;
use warnings;
use Moo::Role;
use JSON::JTL::Syntax::Internal;
use JSON::JTL::Scope;
use Scalar::Util qw( blessed refaddr );
use List::Util   qw( any );
use Sub::Name    qw( subname );

=head1 NAME

JSON::JTL::Transformer - perform transformations

=cut

=head1 METHODS

=head3 transform

  my @results = $self->transform($input, $transformation);

Takes an input document (which should be a parsed JSON value and not a JSON string) and a transformation, which should be a parsed object with a key JTL whose value is 'transformation'.

Returns a nodelist.

=cut


has instruction_spec => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $fn = File::ShareDir::dist_file('JSON-JTL', 'instructionSpec.json');
    open my $fh, '<:encoding(UTF-8)', $fn or die qq(Could not open $fn);
    my $s = '';
    while (<$fh>) { $s .= $_ };
    JSON::decode_json $s;
  },
);

sub get_primary_attribute_name {
  my $self = shift;
  my $instruction = shift;
  my $instruction_spec = $self->instruction_spec;
  $self->throw_error( 'ImplementationError' ) unless exists ( $instruction_spec->{$instruction} );
  return undef unless exists $instruction_spec->{$instruction}->{params};
  return undef unless 'HASH' eq ref $instruction_spec->{$instruction}->{params};
  foreach my $name ( keys %{ $instruction_spec->{$instruction}->{params} } ) {
    return $name if $instruction_spec->{$instruction}->{params}->{$name}->{primary};
  }
  return undef;
}

sub is_primary_attribute {
  my $self        = shift;
  my $instruction = shift;
  my $attribute   = shift;
  my $instruction_spec = $self->instruction_spec;
  $self->throw_error( 'ImplementationError' ) unless exists ( $instruction_spec->{$instruction} );
  return undef unless exists $instruction_spec->{$instruction}->{params};
  return undef unless 'HASH' eq ref $instruction_spec->{$instruction}->{params};
  return $instruction_spec->{$instruction}->{params}->{$attribute}->{primary};
}

sub transform {
  my ($self, $input, $transformation) = @_;
  #my $coreScope = JSON::JTL::Scope::Core->new();
  my $rootScope = $self->subscope( { current => document ($input), instruction => $transformation } );

  $rootScope->evaluate_nodelist_by_attribute('templates') // $self->throw_error('TransformationMissingRequiredAtrribute');

  return $rootScope->apply_templates;
}

=head3 apply_template

  $self->apply_template( $template );

Attempts to apply a single template to the scope, first using C<match_template>, returning undef if that fails; if it succeeds, evaluates C<produce>.

=cut

sub apply_template {
  my ( $self, $template ) = @_;
  my $mergedScope = $template->subscope( { caller => $self, current => $self->current } );

  if ( $mergedScope->match_template ) {
    return ( $mergedScope->evaluate_nodelist_by_attribute( 'produce' ) // throw_error 'TransformationMissingRequiredAtrribute' );
  }

  return undef;
}

=head3 match_template

  $self->match_template( $template  );

Finds the production result of the match. If it is a single boolean true, returns true. Returns false if it is a single boolean false. Throws an error otherwise.

=cut

sub match_template {
  my ( $self ) = @_;
  my $result = $self->evaluate_nodelist_by_attribute( 'match' ) // throw_error 'TransformationMissingRequiredAtrribute';
  $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $result->contents };
  $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $result->contents->[0]->type;
  !!$result->contents->[0];
}

=head3 production_result

  $self->production_result( $production );

Given a production (which must be an arrayref), attempts to evaluate it. Returns the results as an arayref.

=cut

sub production_result {
  my ( $self, $production ) = @_;
  $self->throw_error( 'TransformationUnexpectedType' ) unless 'ARRAY' eq ref $production;
  my $subScope = (
    ( $self->instruction == $production )
    ? $self
    : $self->subscope ( { instruction => $production } )
  );
  my $results = [];
  foreach my $instruction ( @$production ) {
    push @$results, $subScope->subscope ( { instruction => $instruction } )->evaluate_instruction; # should return a nodelist or undef
  }
  return nodelist $results;
}

my $instructions = {
  'applyTemplates' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    return
      $selected->map( sub {
        my $this = shift;
        my $subScope = $self->subscope( { current => $this } );
        $subScope->apply_templates // $subScope->throw_error('TransformationNoMatchingTemplate');
      } );
  },
  'template' => sub {
    my ( $self ) = @_;
    my $template = $self->instruction;
    my @parent   = $self;

    while ( ref ( $parent[0]->instruction ) ne 'ARRAY' ) {
      @parent = $parent[0]->parent;
    }

    $parent[0]->declare_template( $template );
    $parent[0]->parent->parent->declare_template( $template ); # todo: only if in templates

    return void;
  },
  'variable' => sub {
    my ( $self ) = @_;
    my $nameNL   = $self->evaluate_nodelist_by_attribute('name') // $self->throw_error('TransformationMissingRequiredAtrribute');
    my $name     = $nameNL->contents->[0]->value;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // $self->throw_error('TransformationMissingRequiredAtrribute');
    $self->parent->declare_symbol( $name, $selected );
    return void;
  },
  'callVariable' => sub {
    my ( $self ) = @_;
    my $nameNL = $self->evaluate_nodelist_by_attribute('name') // $self->throw_error('TransformationMissingRequiredAtrribute');
    my $name   = $nameNL->contents->[0]->value;
    my $node   = $self->get_symbol( $name ) // $self->throw_error('TransformationUnknownVariable');
    return nodelist [ $node ];
  },
  'current' => sub {
    my ( $self ) = @_;
    nodelist [ $self->current() ];
  },
  'name' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    nodelist [ document $selected->contents->[0]->name ];
  },
  'index' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    nodelist [ document $selected->contents->[0]->index ];
  },
  'parent' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    return $selected->map( sub {
      shift->parent() // ();
    } );
  },
  'children' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    return $selected->map( sub {
      my $children = shift->children();
      return defined $children ? @$children : ();
    } );
  },
  'child' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $which    = $self->evaluate_nodelist_by_attribute('name')
      // $self->evaluate_nodelist_by_attribute('index')
      // $self->throw_error('ImplementationError');
    return $selected->map( sub {
      shift->child( $which->contents->[0]->value ) // ();
    } ) // $self->throw_error('ImplementationError');
  },
  'reverse' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    nodelist [ reverse @{ $selected->contents } ];
  },
  'forEach' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // $self->throw_error('TransformationMissingRequiredAtrribute');
    return $selected->map( sub {
      $self->subscope( { current => shift } )->evaluate_nodelist_by_attribute (
        'produce',
      ) // $self->throw_error('TransformationMissingRequiredAtrribute');
    } );
  },
  'filter' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // $self->throw_error('TransformationMissingRequiredAtrribute');
    return $selected->map( sub {
      my $this     = shift;
      my $subScope = $self->subscope( { current => $this } );
      my $test     = $subScope->evaluate_nodelist_by_attribute('test') // $subScope->throw_error('TransformationMissingRequiredAtrribute');

      $subScope->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $test->contents };
      $subScope->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $test->contents->[0]->type;

      if ( $test->contents->[0]->value ) {
        return $subScope->evaluate_nodelist_by_attribute('produce') // $subScope->current;
      }
      return ();
    } );
  },
  'literal' => sub {
    my ( $self ) = @_;
    my $instruction = $self->instruction;
    if ( exists $instruction->{value} ) {
      return document($instruction->{value})
    } else {
      $self->throw_error('TransformationMissingRequiredAtrribute');
    }
  },
  'array' => sub {
    my ( $self ) = @_;
    my $nodelist = $self->evaluate_nodelist_by_attribute('select') // nodelist();
    return nodelist [ document [ map { $_->value } @{ $nodelist->contents } ] ];
  },
  'object' => sub {
    my ( $self ) = @_;
    my $nodelist = $self->evaluate_nodelist_by_attribute('select') // nodelist();
    return nodelist [ document { map { $_->value } @{ $nodelist->contents } } ];
  },
  'nodeArray' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist();
    return nodelist [ nodeArray [ @{ $selected->contents } ] ];
  },
  'type' => sub {
    my ( $self ) = @_;
    return document ( $self->current->type );
  },
  'if' => sub {
    my ( $self ) = @_;
    my $test = $self->evaluate_nodelist_by_attribute('test') // $self->throw_error('TransformationMissingRequiredAtrribute');
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $test->contents };
    $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $test->contents->[0]->type;
    if ( $test->contents->[0] ) {
      return $self->evaluate_nodelist_by_attribute('produce');
    }
    return nodelist;
  },
  'count' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    return nodelist [ document scalar @{ $selected->contents } ];
  },
  'any' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    foreach my $node (@{ $selected->contents }) {
      my $val = $node->value;
      $self->throw_error('ResultNodeNotBoolean') unless 'boolean' eq valueType $val;
      return nodelist [ truth ] if $val;
    }
    return nodelist [ falsehood ];
  },
  'all' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    foreach my $node (@{ $selected->contents }) {
      my $val = $node->value;
      $self->throw_error('ResultNodeNotBoolean') unless 'boolean' eq valueType $val;
      return nodelist [ falsehood ] unless $val;
    }
    return nodelist [ truth ];
  },
  'not' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $selected->contents };
    $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $selected->contents->[0]->type;
    return nodelist [ ( $selected->contents->[0]->value ) ? falsehood : truth ];
  },
  'or' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute('compare') // $self->throw_error('TransformationMissingRequiredAtrribute');
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $selected->contents };
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $compare->contents };
    $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $selected->contents->[0]->type;
    $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $compare->contents ->[0]->type;
    return nodelist [ ( $selected->contents->[0]->value || $compare->contents ->[0]->value ) ? truth : falsehood ];
  },
  'xor' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute('compare') // $self->throw_error('TransformationMissingRequiredAtrribute');
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $selected->contents };
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $compare->contents };
    $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $selected->contents->[0]->type;
    $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $compare->contents ->[0]->type;
    return nodelist [ ( $selected->contents->[0]->value xor $compare->contents ->[0]->value ) ? truth : falsehood ];
  },
  'and' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute('compare') // $self->throw_error('TransformationMissingRequiredAtrribute');
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $selected->contents };
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $compare->contents };
    $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $selected->contents->[0]->type;
    $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $compare->contents ->[0]->type;
    return nodelist [ ( $selected->contents->[0]->value && $compare->contents ->[0]->value ) ? truth : falsehood ];
  },
  'eq' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute('compare') // $self->throw_error('TransformationMissingRequiredAtrribute');
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $selected->contents };
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $compare->contents };
    return nodelist [ valuesEqual( map { $_->value } map { @{ $_->contents } } $selected, $compare) ];
  },
  'sameNode' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute('compare') // $self->throw_error('TransformationMissingRequiredAtrribute');
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $selected->contents };
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $compare->contents };
    return nodelist [ sameNode ( $selected->contents->[0], $compare->contents->[0] ) ];
  },
  'union' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $test     = $self->instruction->{test} // $self->instruction->{_implicit_argument}; #$self->instruction_attribute('test');

    # todo: custom uniqueness conditions; requires current vs alternate
    my $tester = ( defined $test )
      ? sub {
          my $scope  = shift;
          my $alt    = shift;
          my $both   = nodeArray [ $scope->current, $alt ];
          my $result = $scope->subscope( { current => $both } )->evaluate_nodelist_by_attribute('test');
          $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $result->contents };
          $self->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $result->contents->[0]->type;
          return map { !! $_->value } @{ $result->contents };
        }
      : sub {
        my $scope = shift;
        my $alt   = shift;
        sameNode( $scope->current, $alt );
      };

    my @uniques = ();

    foreach my $node ( @{ $selected->contents } ) {
      my $subScope = $self->subscope( { current => $node } );
      push @uniques, $node unless any { !! $_ } map { $tester->( $subScope, $_ ) } @{[ @uniques ]}; # if this seems odd... it is. It works, but I'm not sure why it refuses to be simplified
    }
    return nodelist [ @uniques ];
  },
  'intersection' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $compared = $self->evaluate_nodelist_by_attribute('compare') // $self->throw_error('TransformationMissingRequiredAtrribute');

    # todo: custom uniqueness conditions; requires current vs alternate
    my $test = sub {
      my $scope = shift;
      my $alt   = shift;
      sameNode( $scope->current, $alt );
    };

    my $intersection = [];

    foreach my $node (@{ $selected->contents } ) {
      my $subScope = $self->subscope( { current => $node } );
      if ( any { $test->( $subScope, $_ ) } @{ $compared->contents } ) {
        push @$intersection, $node unless any { $test->( $subScope, $_ ) } @$intersection
      }
    }

    return nodelist $intersection;
  },
  'true' => sub {
    my ( $self ) = @_;
    nodelist [ truth ];
  },
  'false' => sub {
    my ( $self ) = @_;
    nodelist [ falsehood ];
  },
  'null' => sub {
    my ( $self ) = @_;
    nodelist [ document undef ];
  },
};

# As a developer, I would like more meaningful stack traces than anonymous subroutines
for my $name (keys %$instructions) {
  subname "i_$name", $instructions->{$name};
}

=head3 evaluate_instruction

  $self->evaluate_instruction;

Given an instruction (a hashref with key JTL), evaluates the result. Throws an error if the value of JTL does not correspond to a known instruction.

=cut


sub evaluate_instruction {
  my ( $self ) = @_;
  my $instruction = $self->instruction;
  $self->throw_error('TransformationUnexpectedType' => ("Not a JSON Object")) unless 'HASH' eq ref $instruction;
  my $instructionName = $instruction->{JTL};
  if ( defined ( $instructions->{$instructionName} ) ) {
    return $instructions->{$instructionName}->($self, $instruction);
  }
  $self->throw_error('TransformationUnknownInstruction' => "Cannot understand '$instructionName'");
}

=head3 evaluate_nodelist_by_attribute

  $self->evaluate_nodelist_by_attribute( $instruction, $attribute );

Given an instruction (a hashref with key JTL) and an attribute name, returns a nodelist with the results of the production of the cotents of that attribute.

=cut

sub evaluate_nodelist_by_attribute {
  my ( $self, $attribute ) = @_;
  my $nodeListContents = [];
  my $instruction = $self->instruction;
  if ( exists ( $instruction->{_implicit_argument} ) ) {
    if ( $self->is_primary_attribute ( $instruction->{JTL}, $attribute ) ) {
      return $self->production_result( $instruction->{_implicit_argument} ); # always an arrayref
    }
  }
  if ( exists $instruction->{$attribute} ) {
    return $self->production_result($instruction->{$attribute} ); # always an arrayref
  }
  return undef;
}

1;
