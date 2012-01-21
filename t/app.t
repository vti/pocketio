use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 5;

use_ok('PocketIO');

eval {
    PocketIO->new(app => sub { });
};
like $@ => qr/Either 'handler', 'class' or 'instance' must be specified/;

my $env = {REQUEST_METHOD => 'GET', PATH_INFO => '/1/'};

my $app = PocketIO->new(app => sub { }, handler => sub { });
ok $app->($env);

$app = PocketIO->new(app => sub { }, class => 'Handler');
ok $app->($env);

$app = PocketIO->new(app => sub { }, instance => Handler->new);
ok $app->($env);
