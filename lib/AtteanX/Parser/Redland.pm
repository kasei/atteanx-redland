use v5.14;
use warnings;

package AtteanX::Parser::Redland 0.01 {
	use Attean;
	use Moose;
	use Moose::Util::TypeConstraints;
	use AtteanX::Redland::IRI;
	
	enum 'RedlandTripleSyntaxes', [qw(grddl json ntriples rdfa rdfxml turtle guess)];
	my $ITEM_TYPE = Moose::Meta::TypeConstraint::Role->new(role => 'Attean::API::Triple');
	
	sub handled_type { $ITEM_TYPE }
	
	has 'name'	=> (is => 'ro', isa => 'RedlandTripleSyntaxes', required => 1, default => 'guess');
	has 'world'	=> (is => 'ro', isa => 'Object', required => 1, default => sub { AtteanX::Parser::Redland::RaptorWorld->new();
 });
	has 'base'	=> (is => 'rw', isa => 'IRI', coerce => 1, predicate => 'has_base');
	
	with 'Attean::API::PushParser';

	around BUILDARGS => sub {
		my $orig 	= shift;
		my $class	= shift;
		
		if (scalar(@_) == 1) {
			return $class->$orig(name => shift);
		}
		return $class->$orig(@_);
	};

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
		my $cb		= $self->handler;
		my $base	= $self->has_base ? $self->base->as_string : 'http://example.org/';
		
		my $temp	= '';
		$self->parse_begin($base, $cb);
		while (my $s = $io->read($temp, 2048)) {
			$self->parse_continue($temp, 0);
		}
		$self->parse_continue("\n", 1);
	}
	
	sub parse_cb_from_bytes {
		my $self	= shift;
		my $bytes	= shift;
		my $cb		= $self->handler;
		my $base	= $self->has_base ? $self->base->as_string : 'http://example.org/';
		$self->_parse($bytes, $base, $cb);
	}
}

1;
