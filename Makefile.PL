use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use ExtUtils::PkgConfig;

my %raptor = ExtUtils::PkgConfig->find('raptor2');

my $deps = ExtUtils::Depends->new('AtteanX::Parser::Redland', 'XS::Object::Magic');
$deps->set_inc($raptor{cflags});
$deps->set_libs($raptor{libs});

WriteMakefile(
    NAME => 'AtteanX::Parser::Redland',
    VERSION => '0.01',
    $deps->get_makefile_vars,
    MIN_PERL_VERSION	=> 5.014,
    PREREQ_PM => {
    	'Moose'				=> 0,
    	'Params::Util'		=> 0,
    	'RDF'				=> 0,
    	'XS::Object::Magic'	=> 0,
    },
);
