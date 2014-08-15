use v5.14;
use warnings;

package AtteanX::Parser::Redland 0.01 {
	use Attean;
	use Moose;
	use Moose::Util::TypeConstraints;
	use RDF::Redland2::IRI;
	
	enum 'RedlandTripleSyntaxes', [qw(grddl json ntriples rdfa rdfxml turtle)];
	my $ITEM_TYPE = Moose::Meta::TypeConstraint::Role->new(role => 'Attean::API::Triple');
	
	sub handled_type { $ITEM_TYPE }
	sub canonical_media_type { 'text/turtle' }
	sub media_types {
		return [qw(
				text/turtle
				application/turtle
				application/x-turtle
				application/rdf+xml
				application/json
				text/json
				application/n-triples
				text/html
				application/xhtml+xml
		)]
	}
	
	has 'name'	=> (is => 'ro', isa => 'RedlandTripleSyntaxes', required => 1);
	has 'world'	=> (is => 'ro', isa => 'Object', required => 1);
	has 'base'	=> (is => 'rw', isa => 'IRI', coerce => 1, predicate => 'has_base');
	
	with 'Attean::API::PushParser';

	sub BUILD {
		my $self	= shift;
		$self->build_struct($self->world, $self->name);
	}
	
	sub parse {
		my $self	= shift;
		my $buffer	= shift;
		my $base	= shift;
		my $cb		= shift;
		unless ($base) {
			$base	= 'http://example.org/';
		}
		_parse($self, $buffer, $base, $cb);
	}

	sub parse_cb_from_io {
		my $self	= shift;
		my $io		= shift;
		my $temp	= '';
		my $bytes	= '';
		use Data::Dumper;
		while (my $s = $io->read($temp, 1024)) {
			$bytes	.= $temp;
		}
		return $self->parse_cb_from_bytes($bytes, @_);
	}
	
	sub parse_cb_from_bytes {
		my $self	= shift;
		my $bytes	= shift;
		my $cb		= shift;
		my $base	= $self->has_base ? $self->base->as_string : 'http://example.org/';
		$self->_parse($bytes, $base, $cb);
	}
}

1;
