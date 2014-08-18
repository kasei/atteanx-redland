use v5.14;
use warnings;

package AtteanX::Redland 0.001 {
	use XSLoader;
	use XS::Object::Magic;
	use Attean::API;
	
	BEGIN {
		our $VERSION;
		XSLoader::load('AtteanX::Redland', $VERSION);
	}

	use AtteanX::Redland::IRI;
	use AtteanX::Redland::Blank;
	use AtteanX::Redland::Literal;
}

1;
