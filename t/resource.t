use strict;
use warnings;

use Test::More tests => 11;

use_ok('PocketIO::Resource');

use PocketIO::Pool;

my $d = PocketIO::Resource->new;
my $cb = sub { };

ok !$d->dispatch({REQUEST_METHOD => 'HEAD'}, $cb);
ok !$d->dispatch({REQUEST_METHOD => 'GET', PATH_INFO => '/hello'}, $cb);

ok !PocketIO::Resource->new->dispatch(
    {REQUEST_METHOD => 'GET', PATH_INFO => '/1/websocket/123'}, $cb);

my $res = $d->dispatch({REQUEST_METHOD => 'POST', PATH_INFO => '/1/'}, $cb);
is $res->[0], 200;
is_deeply $res->[1],
  [ 'Connection'     => 'keep-alive',
    'Content-Length' => 79,
    'Content-Type'   => 'text/plain',
  ];
like $res->[2]->[0],
  qr/^\d+:15:25:websocket,flashsocket,htmlfile,jsonp-polling,xhr-polling$/;

$res =
  PocketIO::Resource->new(heartbeat_timeout => 15, close_timeout => 20)
  ->dispatch({REQUEST_METHOD => 'POST', PATH_INFO => '/1/'}, $cb);
is $res->[0], 200;
like $res->[2]->[0],
  qr/^\d+:15:20:websocket,flashsocket,htmlfile,jsonp-polling,xhr-polling$/;

PocketIO::Pool->reset;

$d = PocketIO::Resource->new(max_connections => 1);
$res = $d->dispatch({REQUEST_METHOD => 'POST', PATH_INFO => '/1/'}, $cb);
is $res->[0], 200;
$res = $d->dispatch({REQUEST_METHOD => 'POST', PATH_INFO => '/1/'}, $cb);
is $res->[0], 503;
