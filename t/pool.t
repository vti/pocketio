use strict;
use warnings;

use Test::More tests => 6;

use_ok('PocketIO::Pool');

my $pool = PocketIO::Pool->new;

is_deeply [$pool->connections], [];

ok! $pool->find_connection(123);

my $conn = $pool->add_connection();
ok $conn;

is $conn->id, $pool->find_connection($conn->id)->id;

$pool->remove_connection($conn->id);

ok! $pool->find_connection($conn->id);
