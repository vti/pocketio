use strict;
use warnings;

use Test::More tests => 9;

use_ok('PocketIO::Resource');

use PocketIO::Pool;

my $pool = PocketIO::Pool->new;
my $d    = PocketIO::Resource->new(pool => $pool);
my $cb   = sub { };

ok !$d->dispatch({REQUEST_METHOD => 'HEAD'}, $cb);
ok !$d->dispatch({REQUEST_METHOD => 'GET', PATH_INFO => '/hello'}, $cb);

$pool = PocketIO::Pool->new;
ok !PocketIO::Resource->new(pool => $pool)
  ->dispatch({REQUEST_METHOD => 'GET', PATH_INFO => '/1/websocket/123'}, $cb);

my $res;
my $delayed =
  $d->dispatch({REQUEST_METHOD => 'POST', PATH_INFO => '/1/'}, $cb);
$delayed->(
    sub {
        $res = $_[0];
    }
);
is $res->[0], 200;
is_deeply $res->[1],
  [ 'Content-Type'   => 'text/plain',
    'Connection'     => 'keep-alive',
    'Content-Length' => 79,
  ];
like $res->[2]->[0],
  qr/^\d+:15:25:websocket,flashsocket,htmlfile,xhr-polling,jsonp-polling$/;

$pool    = PocketIO::Pool->new;
$delayed = PocketIO::Resource->new(
    pool              => $pool,
    heartbeat_timeout => 15,
    close_timeout     => 20
)->dispatch({REQUEST_METHOD => 'POST', PATH_INFO => '/1/'}, $cb);
$delayed->(
    sub {
        $res = $_[0];
    }
);
is $res->[0], 200;
like $res->[2]->[0],
  qr/^\d+:15:20:websocket,flashsocket,htmlfile,xhr-polling,jsonp-polling$/;
