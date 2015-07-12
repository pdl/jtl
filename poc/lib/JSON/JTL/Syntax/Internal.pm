package JSON::JTL::Syntax::Internal;
use JSON::JTL::Node;
use JSON::JTL::Document;
use Exporter qw(import);
our @EXPORT = qw(document nodelist);

sub document {
  my $data = shift;
  JSON::JTL::Document->new( { contents => $data } )
}

sub nodelist {
  JSON::JTL::NodeList->new( { contents => [@_] } )
}

1;
