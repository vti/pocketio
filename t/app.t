use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 5;

use_ok('PocketIO');

eval {
    PocketIO->new(app => sub { });
};
like $@ => qr/Either 'handler', 'class' or 'instance' must be specified/;

my $app = PocketIO->new(app => sub { }, handler => sub { });
is ref($app->handler) => 'CODE';

$app = PocketIO->new(app => sub { }, class => 'Handler');
is ref($app->handler) => 'CODE';

$app = PocketIO->new(app => sub { }, instance => Handler->new);
is ref($app->handler) => 'CODE';
