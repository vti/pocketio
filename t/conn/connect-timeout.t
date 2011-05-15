use strict;
use warnings;

use Test::More tests => 3;

use AnyEvent;
use Time::HiRes;

use_ok('PocketIO::Connection');

my $cv = AnyEvent->condvar;

my $failed = 0;
my $conn   = PocketIO::Connection->new(
    connect_timeout      => 0.1,
    on_connection_failed => sub {
        $failed = 1;

        $cv->send;
    }
);

$conn->connecting;

sleep 0.11;

$cv->recv;

ok $failed;

$cv = AnyEvent->condvar;

$failed = 0;
$conn   = PocketIO::Connection->new(
    connect_timeout => 1,
    on_connect      => sub {
        $cv->send;
    },
    on_connection_failed => sub {
        $failed = 1;

        $cv->send;
    }
);

$conn->connecting;
$conn->connected;

$cv->recv;

ok !$failed;
