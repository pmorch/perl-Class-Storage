use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Class::Unbless',
    license             => 'Artistic_2_0',
    dist_author         => q{Peter Valdemar Mørch <peter@morch.com>},
    dist_version_from   => 'lib/Class/Unbless.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
    },
    add_to_cleanup     => [ 'Class-Unbless-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
