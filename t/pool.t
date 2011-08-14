use strict;
use warnings;

use Test::More tests => 5;

use_ok('PocketIO::Pool');

my $pool = PocketIO::Pool->new;

ok !$pool->find_connection(123);

my $conn;
$pool->add_connection(
    sub {
        $conn = shift;
    }
);
ok $conn;

is $conn->id, $pool->find_connection($conn->id)->id;

$pool->remove_connection($conn->id, sub { });

ok !$pool->find_connection($conn->id);
