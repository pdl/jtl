package JSON::JTL::Syntax::Internal;
use JSON::JTL::Node;
use JSON::JTL::Document;
use JSON::JTL::NodeList;
use JSON;
use Exporter qw(import);
our @EXPORT = qw(void document nodelist truth falsehood valuesEqual valueType);
use Scalar::Util qw(blessed looks_like_number);

sub document {
  my $data = shift;
  JSON::JTL::Document->new( { contents => $data } )
}

sub nodelist {
  JSON::JTL::NodeList->new( { contents => $_[0] } )
}

sub void { () };

sub truth {
  document JSON::true;
}

sub falsehood {
  document JSON::false;
}

sub valuesEqual {
  my ( $left, $right ) = @_;
  my $rightType = valueType($left);
  my $leftType  = valueType($right);

  return truth if (
    (
      $leftType eq $rightType
      and (
        (
          $leftType eq 'boolean'
          and
          $left
          ==
          $right
        ) or (
          $leftType eq 'string'
          and
          $left
          eq
          $right
        )
      )
    ) or (
      $leftType =~ /^(?:numeric|integer)$/
      and
      $rightType =~ /^(?:numeric|integer)$/
      and
      $left
      ==
      $right
    )
  );
  if (
    $leftType eq 'object'
    and
    $rightType eq 'object'
  ) {
    return falsehood unless keys %$left == keys %$right;
    return falsehood if grep { ! exists $right->{$_} || ! valuesEqual ( $left->{$_}, $right->{$_} ) } keys %$left;
    return truth;
  } elsif (
    $leftType eq 'array'
    and
    $rightType eq 'array'
  ) {
    return falsehood unless @$left == @$right;
    return falsehood if grep { ! valuesEqual ( $left->[$_], $right->[$_] ) } 0..$#$left;
    return truth;
  }
  return falsehood; # todo: hashes and arrays
}

sub valueType {
  my $val = shift;
  return 'null' unless ( defined $val );
  unless ( ref $val ) {
    return 'integer' if $val =~ /^-?\d+\z/;
    return 'number' if looks_like_number($val);
    return 'string';
  }
  return 'array' if ref $val eq 'ARRAY';
  return 'object' if ref $val eq 'HASH';
  return 'boolean' if ref $val eq 'JSON::Boolean';
  return 'blessed';
}

sub make_instruction {
  my ( $self, $type, $data ) = @_;
  if (ref $type) {
    $data = $type;
    $type = $data->{JTL};
  }
  return $data if blessed $data;
  my $package_type = join '', map ucfirst split /-/, $type;
  my $package = 'JSON::JTL::'.$package_type;
  Module::Load::load($package);
  my $thing = $package->new($data);
  return $thing;
}


1;
