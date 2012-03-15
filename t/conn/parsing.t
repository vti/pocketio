use strict;
use warnings;
use utf8;
use Encode;

use Test::More tests => 7;

use_ok('PocketIO::Connection');

my $conn = PocketIO::Connection->new;
ok $conn;

my $output = '';
$conn->socket->on('message' => sub { $output = $_[1] });

$conn->parse_message('3:1::1234');
is $output => '1234';

$conn->parse_message('3:1::' . encode_utf8('привет'));
is $output => 'привет';

$conn->parse_message('4:1::{"foo":"bar"}');
is_deeply $output => {foo => 'bar'};

$conn->parse_message('4:1::{"foo":"' . encode_utf8('привет') . '"}');
is_deeply $output => {foo => 'привет'};

ok $conn->parse_message('5:1::{"args":["foo"],"name":"foo"}');
