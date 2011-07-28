use strict;
use warnings;

use Test::More tests => 2;

use_ok('PocketIO::Broadcast');

use PocketIO::Pool;
use PocketIO::Broadcast;
use PocketIO::Connection;

my $pool = PocketIO::Pool->new;
my $conn = PocketIO::Connection->new;

my $sockets = PocketIO::Broadcast->new(conn => $conn, pool => $pool);
ok $sockets;

$sockets->send('foo');
$sockets->emit('bar');
