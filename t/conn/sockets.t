use strict;
use warnings;

use Test::More tests => 2;

use_ok('PocketIO::Sockets');

use PocketIO::Pool;

my $pool = PocketIO::Pool->new;

my $sockets = PocketIO::Sockets->new(pool => $pool);
ok $sockets;

$sockets->send('foo');
$sockets->emit('bar');
