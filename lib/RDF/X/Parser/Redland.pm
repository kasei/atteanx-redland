use v5.14;
use warnings;

package RDF::X::Parser::Redland 0.01 {
	use XSLoader;
	use XS::Object::Magic;
	use RDF;
	use Moose;

	has 'name'	=> (is => 'ro', isa => 'Str', required => 1);
	has 'world'	=> (is => 'ro', isa => 'Object', required => 1);
	has 'base'	=> (is => 'rw', isa => 'IRI', coerce => 1, predicate => 'has_base');
	with 'RDF::API::PushParser';

	sub BUILD {
		my $self	= shift;
		$self->build_struct($self->world, $self->name);
	}
	
	my $ITEM_TYPE = Moose::Meta::TypeConstraint::Role->new(role => 'RDF::API::Triple');
	has 'handled_type' => (
		is => 'ro',
		isa => 'Moose::Meta::TypeConstraint',
		init_arg => undef,
		default => sub { $ITEM_TYPE },
	);

	our $VERSION;
	XSLoader::load(__PACKAGE__, $VERSION);

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
