#!/usr/bin/env perl

use v5.14;
use blib;

use Attean;
use RDF::Redland2;
use AtteanX::Parser::Redland;
use Test::More;
use Test::Moose;

my $world	= AtteanX::Parser::Redland::RaptorWorld->new();

{
	my $parser	= Attean->get_parser('Redland')->new(world => $world, name => 'turtle');
	isa_ok($parser, 'AtteanX::Parser::Redland');
	my $type	= $parser->handled_type;
	isa_ok($type, 'Moose::Meta::TypeConstraint::Role');
	is($type->role, 'Attean::API::Triple');
}

{
	my $content	= <<"END";
	<s> <p> 2, 4, 6 .
END
	my $parser	= Attean->get_parser('Redland')->new(world => $world, name => 'turtle', base => 'http://example.org/mybase/');
	my $count	= 0;
	open(my $fh, '<', \$content);
	$parser->parse_cb_from_io($fh, sub {
		my $t	= shift;
		does_ok($t, 'Attean::API::Triple');
		my $s	= $t->subject;
		does_ok($s, 'Attean::API::IRI');
		is($s->value, 'http://example.org/mybase/s');
		
		my $o	= $t->object;
		does_ok($o, 'Attean::API::Literal');
		does_ok($o->datatype, 'Attean::API::IRI');
		is($o->datatype->value, 'http://www.w3.org/2001/XMLSchema#integer');
		my $value	= +($o->value);
		is($value % 2, 0);
		$count++;
	});
	is($count, 3);
}

done_testing();
