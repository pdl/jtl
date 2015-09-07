package JSON::JTL::Syntax::Internal;
use strict;
use warnings;
use JSON;
use Module::Load;
use Exporter qw(import);
our @EXPORT = qw(void document nodelist nodeArray truth falsehood throw_error sameNode valuesEqual valueType);
use Scalar::Util qw(blessed refaddr);

=head1 NAME

JSON::JTL::Syntax::Internal - syntactic sugar to be used within JSON::JTL modules.

=cut

=head1 functions

=head3 document

  document {}
  document 'foo'
  document [ 123 ]

Returns a L<JSON::JTL::Document>. Takes one argument, and this argument becomes the contents of the document object.

=cut

sub document {
  my $data = shift;
  JSON::JTL::Document->new( { contents => $data } )
}

=head3 nodelist

  nodelist []

Returns a L<JSON::JTL::NodeList>. Takes one argument, which must be an arrayref, and this argument becomes the contents of the node list.

=cut

sub nodelist {
  JSON::JTL::NodeList->new( { contents => $_[0] // [] } )
}

=head3 nodeArray

  nodeArray []

Returns a L<JSON::JTL::NodeArray>. Takes one argument, which must be an arrayref, and this argument becomes the contents of the node array.

=cut

sub nodeArray {
  JSON::JTL::NodeArray->new( { contents => $_[0] // [] } )
}

=head3 void

  void

Returns the empty list. This should be used as the return value for C<variable> and other instructions which do not return a nodelist.

=cut

sub void { () };


=head3 truth

  truth

Returns a document containing a single JSON Boolean true node.

=cut

sub truth {
  document JSON::true;
}

=head3 falsehood

  falsehood

Returns a document containing a single JSON Boolean false node.

=cut

sub falsehood {
  document JSON::false;
}

=head3 throw_error

  throw_error 'ResultNodesUnexpectedNumber'

Creates a new L<JTL::Error> object of the type given and throws it.

=cut

sub throw_error {
  JSON::JTL::Error->new( { error_type => $_[0], message => $_[1] } )->throw;
}


=head3 sameNode

  sameNode($left, $right)

Given two nodes, tests if they are the same node, i.e. they have the same document and the same path.

=cut

sub sameNode {
  my ( $left, $right ) = @_;
  my ( $leftPath, $rightPath ) = map { $_->path } @_;

  return truth if
    refaddr ( $left->document )
    ==
    refaddr ( $right->document )
    and
    @{ $leftPath }
    ==
    @{ $rightPath }
    and
    !grep {
      $leftPath->[$_]
      ne
      $rightPath->[$_]
    } 0 .. $#{ $leftPath };
  return falsehood;
}

=head3 valuesEqual

  valuesEqual($left, $right)

Given two values, tests if they are of the same type and equal.

=cut

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
      $leftType eq 'number'
      and
      $rightType eq 'number'
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

=head3 valueType

  valueType($value)

Returns any of 'object', 'array', 'string', 'number', or 'boolean', depending on the value passed in as the first argument.

=cut


sub valueType {
  my $val = shift;
  return 'null' unless ( defined $val );
  my $ref = ref $val;
  unless ( $ref ) {
    return 'number' if _is_number($val);
    return 'string';
  }
  return 'array' if $ref eq 'ARRAY';
  return 'object' if $ref eq 'HASH';
  return 'boolean' if $ref =~ 'Boolean';
  return 'blessed';
}

sub _is_number {
  $_[0] eq ''
    ? 0
    : substr($_[0]^$_[0],0,1) ne "\c@";
}

# These come last otherwise there will be load order problems
Module::Load::load 'JSON::JTL::Document';
Module::Load::load 'JSON::JTL::Error';
Module::Load::load 'JSON::JTL::Node';
Module::Load::load 'JSON::JTL::NodeList';
Module::Load::load 'JSON::JTL::NodeArray';

1;
