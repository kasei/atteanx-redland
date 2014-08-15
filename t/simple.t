#!/usr/bin/env perl

use v5.14;
use blib;

use RDF::Redland2;
use AtteanX::Parser::Redland;
use Test::More;
use Test::Moose;
use Data::Dumper;

my $world = AtteanX::Parser::Redland::RaptorWorld->new();
{
	note('Turtle');
	my $p = AtteanX::Parser::Redland->new(world => $world, name => 'turtle');
	isa_ok($p, 'AtteanX::Parser::Redland');
	my $content	= <<"END";
	<s> <p> <o>, 1, 2.0 .
END
	my $count	= 0;
	my $base	= 'http://example.org/base/';
	$p->parse($content, $base, sub {
		my $t	= shift;
		does_ok($t, 'Attean::API::Triple');
		my $s	= $t->subject;
		does_ok($s, 'Attean::API::IRI');
		is($s->value, 'http://example.org/base/s');
		$count++;
	});
	is($count, 3);
}

{
	note('RDF/XML');
	my $content	= <<'END';
<rdf:Description rdf:about="http://www.w3.org/TR/rdf-syntax-grammar"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:ex="http://example.org/stuff/1.0/">
  <ex:editor>
    <rdf:Description />
  </ex:editor>
  <dc:title>RDF 1.1 XML Syntax</dc:title>
</rdf:Description>
END
	my $p = AtteanX::Parser::Redland->new(world => $world, name => 'rdfxml');
	isa_ok($p, 'AtteanX::Parser::Redland');
	my $count	= 0;
	my $base	= 'http://example.org/base/';
	$p->parse($content, $base, sub {
		my $t	= shift;
		does_ok($t, 'Attean::API::Triple');
		my $s	= $t->subject;
		does_ok($s, 'Attean::API::IRI');
		is($s->value, 'http://www.w3.org/TR/rdf-syntax-grammar');
		$count++;
	});
	is($count, 2);
}

done_testing();