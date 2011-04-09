use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 4;

use_ok('Plack::Middleware::SocketIO');

eval {
    Plack::Middleware::SocketIO->new(app => sub { });
};
like $@ => qr/Either 'handler' or 'class' must be specified/;

my $middleware =
  Plack::Middleware::SocketIO->new(app => sub { }, handler => sub { });
is ref($middleware->handler) => 'CODE';

$middleware =
  Plack::Middleware::SocketIO->new(app => sub { }, class => 'Handler');
is ref($middleware->handler) => 'CODE';
