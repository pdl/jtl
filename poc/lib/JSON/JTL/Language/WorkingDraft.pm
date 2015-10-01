package JSON::JTL::Language::WorkingDraft;
use strict;
use warnings;
use Moo;
use JSON::JTL::Syntax::Internal;
use JSON::JTL::Scope;
use Scalar::Util qw( blessed refaddr );
use List::Util   qw( any max );
use Sub::Name    qw( subname );

=head1 NAME

JSON::JTL::Language::WorkingDraft - store information about the current working draft version of JTL

=head1 DESCRIPTION

This class is a role which provides implementations for the core instructions in JTL. It is not meant to be used directly.

You should only need to interact with this module if you are a developer of this perl package or of a plugin: if you are just writing JTL, you want to be reading L<JSON::JTL>.

=head1 ATTRIBUTES

=head3 instruction_spec

A copy of the instruction specification C<instructionSpec.json>, as a perl data structure.

=cut

my $instructions;

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

=head1 METHODS

=head3 get_instruction

Returns a coderef representing the implementation of an instruction, which takes a single argument, a L<JSON::JTL::Scope>.

Returns undef if no implementation exists.

=cut

sub get_instruction {
  return $instructions->{$_[1]};
}

=head3 get_primary_attribute_name

  $self->get_primary_attribute_name('eq'); # returns 'compare'

Returns the name of the 'primary' attribute, i.e. the one which describes the most important attribute other than select. Used for the resolution of implicit arguments.

=cut

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

=head3 is_primary_attribute

  $self->is_primary_attribute_name('eq', 'compare'); # returns a true value

Returns a true value if the attribute given as the second argument is the primary attribute of the instruction given as the first.

Returns a false value (typically undef) otherwise.

=cut

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

sub _tester_from_test {
  my $test = shift;
  return ( defined $test )
    ? sub {
        my $scope  = shift;
        my $alt    = shift;
        my $both   = nodeArray [ $scope->current, $alt ];
        my $result = $scope->subscope( { current => $both } )->evaluate_nodelist_by_attribute('test');
        $scope->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $result->contents };
        $scope->throw_error('ResultNodeNotBoolean'    ) unless 'boolean' eq $result->contents->[0]->type;
        return !! ${ $result->contents }[0]->value;
      }
    : sub {
      my $scope = shift;
      my $alt   = shift;
      sameNode( $scope->current, $alt );
    };
}

$instructions = {
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
    return nodelist [ $self->enclose ];
  },
  'declareTemplates' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];

    $selected->map( sub {
      my $this   = shift;
      my @parent = $self;

      while ( ref ( $parent[0]->instruction ) ne 'ARRAY' ) {
        @parent = $parent[0]->parent;
      }

      $parent[0]->declare_template( $this );

      void;
    } );

    return void;
  },
  'variable' => sub {
    my ( $self ) = @_;
    my $nameNL   = $self->evaluate_nodelist_by_attribute('name') // $self->throw_error('TransformationMissingRequiredAtrribute');
    my $name     = $nameNL->contents->[0]->value;
    my $selected = $self->evaluate_nodelist_by_attribute('select')  // nodelist [ $self->current ];
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
    $selected->map( sub { my $name = $_->name; defined $name ? document $name : return; } );
  },
  'index' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    $selected->map( sub { my $index = $_->index; defined $index ? document $index : return; } );
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
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $selected->contents };
    return document ( $selected->contents->[0]->type );
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
  'reduce' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $length   = @{ $selected->contents };
    $self->throw_error('ResultNodesUnexpectedNumber') unless $length >= 2;
    my $current  = $selected->contents->[0];
    my $last     = $length - 1;

    for my $i ( 1..$last ) {
      my $subscope = $self->subscope( { current => nodeArray [ $current, $selected->contents->[$i] ] } );
      my $l        = $subscope->evaluate_nodelist_by_attribute('produce');
      $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $l->contents };
      $current = $l->contents->[0];
    }

    return $current;
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
  'zip' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $arrays   = [ grep { !!@$_ } map { $_->value } @{ $selected->contents } ];
    my $extent   = max ( map { $#$_ } @$arrays );
    my $results  = [];

    return nodelist nodeArray [] unless $extent;

    for my $i (0..$extent) {
      push @$results, document [ map {
        $_->[$i%@$_]
      } @$arrays ];
    }

    return nodelist [ nodeArray $results ];
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

    return nodelist [ falsehood ] unless @{ $selected->contents } == @{ $compare->contents };

    for my $i ( 0..$#{ $selected->contents } ) {
      return nodelist [ falsehood ]
        unless valuesEqual(
          $selected->contents->[$i]->value,
          $compare->contents->[$i]->value
        );
    }

    return nodelist [ truth ];
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
    my $tester   = _tester_from_test ( $test );

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
    my $test     = $self->instruction->{test} // $self->instruction->{_implicit_argument}; #$self->instruction_attribute('test');
    my $tester   = _tester_from_test ( $test );

    my $intersection = [];

    foreach my $node ( @{ $selected->contents } ) {
      my $subScope = $self->subscope( { current => $node } );
      if ( any { $tester->( $subScope, $_ ) } @{ $compared->contents } ) {
        push @$intersection, $node unless any { $tester->( $subScope, $_ ) } @$intersection
      }
    }

    return nodelist $intersection;
  },
  'symmetricDifference' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $compared = $self->evaluate_nodelist_by_attribute('compare') // $self->throw_error('TransformationMissingRequiredAtrribute');
    my $test     = $self->instruction->{test} // $self->instruction->{_implicit_argument}; #$self->instruction_attribute('test');
    my $tester   = _tester_from_test ( $test );

    my $sd = [];

    foreach my $node (  @{ $selected->contents } ) {
      my $subScope = $self->subscope( { current => $node } );
      if ( ! any { $tester->( $subScope, $_ ) } @{ $compared->contents } ) {
        push @$sd, $node unless any { $tester->( $subScope, $_ ) } @$sd;
      }
    }

    foreach my $node ( @{ $compared->contents } ) {
      my $subScope = $self->subscope( { current => $node } );
      if ( ! any { $tester->( $subScope, $_ ) } @{ $selected->contents } ) {
        push @$sd, $node unless any { $tester->( $subScope, $_ ) } @$sd;
      }
    }

    return nodelist $sd;
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
  'range' => sub {
    my ( $self ) = @_;
    my $selected = $self->evaluate_nodelist_by_attribute('select') // nodelist [ $self->current ];
    my $compare  = $self->evaluate_nodelist_by_attribute('end') // $self->throw_error('TransformationMissingRequiredAtrribute');

    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $selected->contents };
    $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $compare->contents };

    my $start = $selected->contents->[0]->value;
    my $end   = $compare->contents->[0]->value;

    $self->throw_error('ResultNodeUnexpectedType') unless 'number' eq valueType($start);
    $self->throw_error('ResultNodeUnexpectedType') unless 'number' eq valueType($end);

    $self->throw_error('ResultNodeUnexpectedType') unless $start == int $start;
    $self->throw_error('ResultNodeUnexpectedType') unless $end   == int $end;

    return nodelist [ map { document $_ }
      $start > $end
      ? reverse ($end..$start)
      : $start..$end
    ];
  },
};

# As a developer, I would like more meaningful stack traces than anonymous subroutines
for my $name (keys %$instructions) {
  subname "i_$name", $instructions->{$name};
}

1;
