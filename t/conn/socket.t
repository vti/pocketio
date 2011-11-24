use strict;
use warnings;

use Test::More tests => 2;

use_ok('PocketIO::Socket');

my $socket = PocketIO::Socket->new;
ok $socket;
