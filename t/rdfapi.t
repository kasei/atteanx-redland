#!/usr/bin/env perl

use v5.14;
use blib;

use RDF;
use RDF::X::Parser::Redland;
use Test::More;
use Test::Moose;

my $world	= RDF::X::Parser::Redland::RaptorWorld->new();

{
	my $parser	= RDF->get_parser('Redland')->new(world => $world, name => 'turtle');
	isa_ok($parser, 'RDF::X::Parser::Redland');
	my $type	= $parser->handled_type;
	isa_ok($type, 'Moose::Meta::TypeConstraint::Role');
	is($type->role, 'RDF::API::Triple');
}

{
	my $content	= <<"END";
	<s> <p> 2, 4, 6 .
END
	my $parser	= RDF->get_parser('Redland')->new(world => $world, name => 'turtle', base => 'http://example.org/mybase/');
	my $count	= 0;
	open(my $fh, '<', \$content);
	$parser->parse_cb_from_io($fh, sub {
		my $t	= shift;
		isa_ok($t, 'RDF::Triple');
		my $s	= $t->subject;
		does_ok($s, 'RDF::API::IRI');
		is($s->as_string, 'http://example.org/mybase/s');
		
		my $o	= $t->object;
		does_ok($o, 'RDF::API::Literal');
		isa_ok($o->datatype, 'IRI');
		is($o->datatype->as_string, 'http://www.w3.org/2001/XMLSchema#integer');
		my $value	= +($o->value);
		is($value % 2, 0);
		$count++;
	});
	is($count, 3);
}

done_testing();
