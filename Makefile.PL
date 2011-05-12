#!/usr/bin/env perl

use 5.008007;

use strict;
use warnings;

use ExtUtils::MakeMaker;

my ($mm) = $ExtUtils::MakeMaker::VERSION =~ /^([^_]+)/;

WriteMakefile(
    NAME         => 'PocketIO',
    VERSION_FROM => 'lib/PocketIO.pm',
    ABSTRACT     => 'Socket.IO Plack app',
    AUTHOR       => 'Viacheslav Tykhanovskyi <vti@cpan.org>',

    ($mm < 6.3002 ? () : ('LICENSE' => 'artistic_2')),

    (   $mm < 6.46
        ? ()
        : ( META_MERGE => {
                requires  => {perl => '5.008007'},
                resources => {
                    license => 'http://dev.perl.org/licenses/',
                    repository =>
                      'http://github.com/vti/pocketio',
                    bugtracker =>
                      'http://github.com/vti/pocketio/issues'
                },
                no_index => {directory => [qw/t/]}
            },
            META_ADD => {
                build_requires     => {},
                configure_requires => {}
            },
        )
    ),

    PREREQ_PM => {
        'AnyEvent'            => 0,
        'HTTP::Body'          => 0,
        'JSON'                => 0,
        'Plack'               => 0,
        'Protocol::WebSocket' => 0.009002,
        'Scalar::Util'        => 0,
        'Try::Tiny'           => 0
    },
    test => {TESTS => 't/*.t t/*/*.t'}
);
