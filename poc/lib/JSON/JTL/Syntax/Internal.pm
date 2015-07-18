package JSON::JTL::Syntax::Internal;
use JSON::JTL::Node;
use JSON::JTL::Document;
use JSON::JTL::NodeList;
use JSON;
use Exporter qw(import);
our @EXPORT = qw(void document nodelist truth falsehood);
use Scalar::Util qw(blessed);

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
