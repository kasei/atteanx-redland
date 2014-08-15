use v5.14;
use warnings;

package RDF::Redland2::Literal 0.001 {
	use RDF::Redland2;
	use Moose;

	has 'ntriples_string'	=> (is => 'ro', isa => 'Str', lazy => 1, builder => '_ntriples_string');
	with 'Attean::API::Literal';
}

1;
