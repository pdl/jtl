package JSON::JTL::Plugins::Syntax::Receiver;
use Pegex::Base;
extends 'Pegex::JSON::Data';

sub got_jtls {
  return pop;
}

sub got_explicitArguments {
  +{ map @$_, map @$_, @{(pop)} }
}

sub got_implicitArguments {
  +{ _implicit_argument => @{(pop)} }
}

sub got_instruction {
  shift;
  return { JTL => $_[0][0], %{ $_[0][1] } };
}

sub got_nameToken {
  return pop;
}

sub got_filter {
  return { JTL => 'filter', test => (pop)->[0] };
}

sub got_step {
  shift;
  return { JTL => '_parser_step', filter => pop };
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

sub got_pathExpression {
  shift;
  #if ( $_[0][1]->{step} ne 'any' ) {

  #}
  return { JTL => $_[0][0]->{anchor},  };
}

sub got_stepAny {
  shift;
  return { JTL => '_parser_step', step => 'any' };
}

sub got_stepNameToken {
  shift;
  return { JTL => '_parser_step', step => 'name', value => $_[0] };
}

sub got_stepString {
  shift;
  return { JTL => '_parser_step', step => 'name', value => $_[0] };
}

sub got_stepNumber {
  shift;
  return { JTL => '_parser_step', step => 'index', value => $_[0] };
}

1;
