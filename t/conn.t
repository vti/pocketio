use strict;
use warnings;

use Test::More tests => 7;

use_ok('PocketIO::Connection');

my $conn = PocketIO::Connection->new;
ok $conn;

my $output = '';
$conn->on_message(sub { $output .= $_[1] });

$conn->read('~m~4~m~1234');
is $output => '1234';
$output = '';

$conn->read('~m~4~m~1234~m~2~m~12');
is $output => '123412';
$output = '';

$conn->read('foobar');
is $output => '';

$conn->on_message(sub { $output = $_[1] });

$conn->read('~m~16~m~~j~{"foo":"bar"}');
is_deeply $output => {foo => 'bar'};
$output = '';

$conn->read('~m~16~m~~j~{"foo","bar"}');
is $output => '';
