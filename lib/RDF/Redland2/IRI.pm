use v5.14;
use warnings;

package RDF::Redland2::IRI 0.001 {
	use RDF::Redland2;
	use Moose;

	# NOTE: Objects of this class are not meant to be constructed from perl.
	#       They should only be constructed from within the XS code that is a
	#       part of this package, allowing an underlying raptor structure to be
	#       associated with the perl-level object.
	
	has 'ntriples_string'	=> (is => 'ro', isa => 'Str', lazy => 1, builder => '_ntriples_string');
	with 'Attean::API::IRI';
}

1;
