#!/usr/bin/env perl

use v5.14;
use blib;

use RDF::X::Parser::Redland;
use Test::More;
use Data::Dumper;

my $content	= <<"END";
<s> <p> <o>, 1, 2.0 .
END
my $world = RDF::X::Parser::Redland::RaptorWorld->new();
my $p = RDF::X::Parser::Redland->new(world => $world, name => q[turtle]);
isa_ok($p, 'RDF::X::Parser::Redland');
{
	my $count	= 0;
	my $base	= 'http://example.org/base/';
	$p->parse($content, $base, sub {
		my $t	= shift;
		isa_ok($t, 'RDF::Triple');
		my $s	= $t->subject;
		isa_ok($s, 'RDF::IRI');
		is($s->as_string, 'http://example.org/base/s');
		$count++;
	});
	is($count, 3);
}

done_testing();