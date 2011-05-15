use strict;
use warnings;

use Test::More tests => 6;

use_ok('PocketIO::Pool');

is_deeply [PocketIO::Pool->connections], [];

ok! PocketIO::Pool->find_connection(123);

my $conn = PocketIO::Pool->add_connection();
ok $conn;

is $conn->id, PocketIO::Pool->find_connection($conn->id)->id;

PocketIO::Pool->remove_connection($conn->id);

ok! PocketIO::Pool->find_connection($conn->id);
