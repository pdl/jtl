package JSON::JTL::Plugins::Syntax::Receiver;
use strict;
use warnings;
use Pegex::Base;
use JSON;
extends 'Pegex::JSON::Data';

sub _lit {
  { JTL => 'literal', value => shift }
}

sub got_jtls {
  return pop;
}

sub got_explicitArguments {
  +{ map @$_, map @$_, @{(pop)} }
}

sub got_implicitArguments {
  my $args = pop;
  @$args ? +{ _implicit_argument => $args } : +{};
}

sub got_argumentList {
  shift;
  return [ map @$_, @{(pop)} ];
}

sub got_instruction {
  shift;
  return pop;
}

sub got_functionalInstruction {
  shift;
  return { JTL => $_[0][0], %{ $_[0][1] } };
}

sub got_chainedInstruction {
  shift;
  #my $infix = shift @{$_[0]};
  return { JTL => $_[0][0], %{ $_[0][1] } };
}

sub got_instructionChain {
  shift;
  my $chain   = $_[0][1];
  my @current = @{ $_[0][0] };
  while ( @$chain ) {
    my $prev = [ @current ];
    @current = shift @$chain;
    $current[0]->{select} = $prev;
  }
  return $current[0];
}

sub got_chainLoneArgument {
  shift;
  return [ pop ];
}

sub got_loneArgument {
  shift;
  return [ pop ];
}

sub got_nameToken {
  return pop;
}


sub got_variableCall {
  return { JTL => 'callVariable', name => [ _lit ( pop->[0] ) ] };
}

sub got_literal {
  return _lit pop->[0];
}

sub got_filter {
  return { JTL => 'filter', test => [ (pop)->[0] ] };
}

sub got_anchorChild {
  return { JTL => '_parser_anchor', anchor => 'child' };
}

sub got_anchorParent {
  return { JTL => '_parser_anchor', anchor => 'parent' };
}

sub got_anchorRoot {
  return { JTL => '_parser_anchor', anchor => 'root' };
}

sub got_string { pop }

sub got_doublestring { Pegex::JSON::Data::got_string(@_) }

my %singlestring_escapes = (
  "'" => "'",
  '/' => "/",
  "\\" => "\\",
  b => "\b",
  f => "\x12",
  n => "\n",
  r => "\r",
  t => "\t",
);

sub got_singlestring { # as Pegex::JSON::Data::got_string but with the regex in the second part changed
    my $string = pop;
    $string =~ s/\\(['\/\\bfnrt])/$singlestring_escapes{$1}/ge;
    # This handles JSON encoded Unicode surrogate pairs
    $string =~ s/\\u([0-9a-f]{4})\\u([0-9a-f]{4})/pack "U*", hex("$1$2")/ge;
    $string =~ s/\\u([0-9a-f]{4})/pack "U*", hex($1)/ge;
    return $string;
}

sub got_pathExpression {
  shift;
  my $steps = [];
  my $expression;

  if ( ( $_[0][0]->{JTL} // '' ) eq 'callVariable' ) {
    $expression = $_[0][0]
  } elsif ( $_[0][0]->{anchor} eq 'parent' ) {
    $expression = { JTL => 'parent' }
  } elsif ( $_[0][0]->{anchor} eq 'root' ) {
    $expression = { JTL => 'root' }
  }

  foreach my $step_and_filter ( @{ $_[0][1] } ) {
    my ( $step, $filter ) = @$step_and_filter;
    $expression = (
      ( $step->{step} eq 'self' )
      ? $expression
      : ( $step->{step} eq 'parent' )
        ? { JTL => 'parent',  ( $expression ? ( select => [ $expression ] ) : () )  }
        : ( $step->{step} eq 'any' )
          ? { JTL => 'children', ( $expression ? ( select => [ $expression ] ) : () ) }
          : { JTL => 'child', $step->{step} => [ $step->{value} ], ( $expression ? ( select => [ $expression ] ) : () ) }
    );
    if ( $filter ) {
      $expression = { %$filter, select => [ $expression ] };
    }
  }

  return $expression;
}

sub got_stepAny {
  shift;
  return { JTL => '_parser_step', step => 'any' };
}

sub got_stepParent {
  shift;
  return { JTL => '_parser_step', step => 'parent' };
}

sub got_stepSelf {
  shift;
  return { JTL => '_parser_step', step => 'self' };
}

sub got_stepNameToken {
  shift;
  return { JTL => '_parser_step', step => 'name', value => _lit $_[0] };
}

sub got_stepString {
  shift;
  return { JTL => '_parser_step', step => 'name', value => _lit $_[0] };
}

sub got_stepNumber {
  shift;
  return { JTL => '_parser_step', step => 'index', value => _lit 0+$_[0] }; # 0+ coerces to number which is very important!
}


sub got_true  { JSON::true }
sub got_false { JSON::false }

1;
