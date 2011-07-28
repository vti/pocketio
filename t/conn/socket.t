use strict;
use warnings;

use Test::More tests => 3;

use_ok('PocketIO::Socket');

my $socket = PocketIO::Socket->new;
ok $socket;

my $foo;
$socket->on('foo', sub {$foo = 1});
$socket->emit('foo');
is $foo, 1;
