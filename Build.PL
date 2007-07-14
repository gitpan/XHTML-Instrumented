use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name   => 'XHTML::Instrumented',
    dist_version => '0.04',
    license       => 'perl',
    requires => {
	'perl'		=> '5.6.0',
	'Params::Validate' => 0,
	'XML::Parser' => 0,
    },
    build_requires => {
	'Test::XML' => 0,
	'Test::Warn' => 0,
    },
    recommends => {
	'Test::XML::Order' => '0.03',
        'Test::Pod' => 0,
    },
    sign           => 1,
    create_makefile_pl => 'traditional',
);

$builder->create_build_script;
