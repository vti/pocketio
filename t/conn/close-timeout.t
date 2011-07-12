use strict;
use warnings;

use Test::More tests => 2;

use AnyEvent;
use Time::HiRes;

use_ok('PocketIO::Connection');

my $cv = AnyEvent->condvar;

my $failed;
my $conn = PocketIO::Connection->new(
    close_timeout => 0.1,
    on_close      => sub {
        $failed = 1;

        $cv->send;
    }
);
$conn->connected;

sleep 0.11;

$cv->recv;

ok $failed;
