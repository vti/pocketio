use strict;
use warnings;

use Test::More tests => 3;

use_ok('PocketIO::Resource');

ok !PocketIO::Resource->dispatch({PATH_INFO => '123'},    sub { });
ok !PocketIO::Resource->dispatch({PATH_INFO => '/hello'}, sub { });
