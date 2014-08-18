use v5.14;
use warnings;

package RDF::Redland2 0.001 {
	use XSLoader;
	use XS::Object::Magic;
	use Attean::API;
	
	BEGIN {
		our $VERSION;
		XSLoader::load('RDF::Redland2', $VERSION);
	}

	use RDF::Redland2::IRI;
	use RDF::Redland2::Blank;
	use RDF::Redland2::Literal;
}

1;
