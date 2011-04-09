use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 5;

use_ok('Plack::Middleware::SocketIO');

use Handler;

eval {
    Plack::Middleware::SocketIO->new(app => sub { });
};
like $@ => qr/Either 'handler', 'class' or 'instance' must be specified/;

my $middleware =
  Plack::Middleware::SocketIO->new(app => sub { }, handler => sub { });
is ref($middleware->handler) => 'CODE';

$middleware =
  Plack::Middleware::SocketIO->new(app => sub { }, class => 'Handler');
is ref($middleware->handler) => 'CODE';

$middleware =
  Plack::Middleware::SocketIO->new(app => sub { }, instance => Handler->new);
is ref($middleware->handler) => 'CODE';
