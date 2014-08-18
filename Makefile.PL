use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use ExtUtils::PkgConfig;

my %raptor = ExtUtils::PkgConfig->find('raptor2');

my $deps = ExtUtils::Depends->new('AtteanX::Redland', 'XS::Object::Magic');
$deps->set_inc($raptor{cflags});
$deps->set_libs($raptor{libs});

WriteMakefile(
    NAME => 'AtteanX::Redland',
    VERSION => '0.001',
    $deps->get_makefile_vars,
    MIN_PERL_VERSION	=> 5.014,
    PREREQ_PM => {
    	'Moose'				=> 0,
    	'Params::Util'		=> 0,
    	'Attean'			=> 0,
    	'XS::Object::Magic'	=> 0,
    },
);
