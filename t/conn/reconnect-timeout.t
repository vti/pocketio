use strict;
use warnings;

use Test::More tests => 3;

use AnyEvent;
use Time::HiRes;

use_ok('PocketIO::Connection');

my $cv = AnyEvent->condvar;

my $failed = 0;
my $conn   = PocketIO::Connection->new(
    reconnect_timeout   => 0.1,
    on_reconnect_failed => sub {
        shift->disconnected;
    },
    on_disconnect => sub {
        $failed = 1;

        $cv->send;
    }
);

$conn->connected;
$conn->reconnecting;

sleep 0.11;

$cv->recv;

ok $failed;

$cv = AnyEvent->condvar;

$failed = 0;
$conn   = PocketIO::Connection->new(
    reconnect_timeout => 1,
    on_reconnect      => sub {
        $cv->send;
    }
);

$conn->connected;
$conn->reconnecting;
$conn->reconnected;

$cv->recv;

ok !$failed;
