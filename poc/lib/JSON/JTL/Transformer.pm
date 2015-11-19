package JSON::JTL::Transformer;
use strict;
use warnings;
use Moo::Role;
use JSON::JTL::Syntax::Internal;
use JSON::JTL::Scope;
use Module::Load;

=head1 NAME

JSON::JTL::Transformer - perform transformations

=head1 DESCRIPTION

This class is a role which provides transformation-related methods to JSON::JTL::Scope, and is not meant to be used directly.

You should only need to interact with this module if you are a developer of this perl package or of a plugin: if you are just writing JTL, you want to be reading L<JSON::JTL>.

=cut

=head1 ATTRIBUTES

=head3 language

An instance of the language, currently always L<JSON::JTL::Language::WorkingDraft>.

=cut

has language => (
  is      => 'ro',
  default => sub {
    Module::Load::load('JSON::JTL::Language::WorkingDraft');
    JSON::JTL::Language::WorkingDraft->new;
  }
);

=head1 METHODS

=head3 transform

  my @results = $self->transform($input, $transformation);

Takes an input document (which should be a parsed JSON value and not a JSON string) and a transformation, which should be a parsed object with a key JTL whose value is 'transformation'.

Returns a nodelist.

=cut

sub transform {
  my ($self, $input, $transformation) = @_;
  #my $coreScope = JSON::JTL::Scope::Core->new();
  my $rootScope = $self->subscope( { current => document ($input), instruction => $transformation } );

  my $templates = $rootScope->evaluate_nodelist_by_attribute('templates') // $self->throw_error('TransformationMissingRequiredAtrribute');

  $rootScope->declare_template($_) for @{ $templates->contents };

  $rootScope->apply_templates;
}

=head3 apply_template

  $self->apply_template( $template );

Attempts to apply a single template to the scope, first using C<match_template>, returning undef if that fails; if it succeeds, evaluates C<produce>.

=cut

sub apply_template {
  my ( $self, $template, $options ) = @_;
  my $mergedScope = $template->subscope( { caller => $self, current => $self->current } );

  if ( $mergedScope->match_template($options) ) {
    return ( $mergedScope->evaluate_nodelist_by_attribute( 'produce' ) // $self->throw_error('TransformationMissingRequiredAtrribute') );
  }

  return undef;
}

=head3 match_template

  $self->match_template( $template  );

Finds the production result of the match. If it is a single boolean true, returns true. Returns false if it is a single boolean false. Throws an error otherwise.

=cut

sub match_template {
  my ( $self, $options ) = @_;

  $options //= {};

  # First, we check if the name of the template is the name we have been given.

  my $name = $self->evaluate_nodelist_by_attribute( 'name' ) // undef; # todo: we should really have done this at compile time

  if ( defined $name ) {
    if ( @{ $name->contents } ) {
      $self->throw_error('ResultNodesMultipleNodes') unless 1 == @{ $name->contents };
      $name = $name->contents->[0]->value;
    } else {
      $name = undef;
    }

    return undef unless ( valuesEqual ( $name, $options->{name} ) );
  }

  my $result = $self->evaluate_nodelist_by_attribute( 'match' ) // return 1;
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

=head3 evaluate_instruction

  $self->evaluate_instruction;

Given an instruction (a hashref with key JTL), evaluates the result. Throws an error if the value of JTL does not correspond to a known instruction.

=cut


sub evaluate_instruction {
  my ( $self ) = @_;
  my $instruction = $self->instruction;
  $self->throw_error('TransformationUnexpectedType' => ("Not a JSON Object")) unless 'HASH' eq ref $instruction;
  my $instructionName = $instruction->{JTL} // $self->throw_error('TransformationUnknownInstruction' => "Not a JTL instruction");
  if ( defined ( my $implementation = $self->language->get_instruction( $instructionName ) ) ) {
    return $implementation->($self, $instruction);
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
    if ( $self->language->is_primary_attribute ( $instruction->{JTL}, $attribute ) ) {
      return $self->production_result( $instruction->{_implicit_argument} ); # always an arrayref
    }
  }
  if ( exists $instruction->{$attribute} ) {
    return $self->production_result($instruction->{$attribute} ); # always an arrayref
  }
  return undef;
}

1;
