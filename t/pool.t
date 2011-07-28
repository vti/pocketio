use strict;
use warnings;

use Test::More tests => 7;

use_ok('PocketIO::Pool');

my $pool = PocketIO::Pool->new;

is $pool->size, 0;

ok! $pool->find_connection(123);

my $conn = $pool->add_connection();
ok $conn;
is $pool->size, 1;

is $conn->id, $pool->find_connection($conn->id)->id;

$pool->remove_connection($conn->id);

ok! $pool->find_connection($conn->id);
