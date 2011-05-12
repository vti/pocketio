use strict;
use warnings;
use utf8;
use Encode;

use Test::More tests => 13;

use_ok('PocketIO::Connection');

my $conn = PocketIO::Connection->new;
ok $conn;

my $output = '';
$conn->on_message(sub { $output .= $_[1] });

$conn->read('~m~4~m~1234');
is $output => '1234';
$output = '';

$conn->read('~m~6~m~' . encode_utf8('привет'));
is $output => 'привет';
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

$conn->read('~m~19~m~~j~{"foo":"' . encode_utf8('привет') . '"}');
is_deeply $output => {foo => 'привет'};
$output = '';

$conn->read('~m~16~m~~j~{"foo","bar"}');
is $output => '';

is $conn->build_message('foo') => '~m~3~m~foo';
is $conn->build_message({foo => 'bar'}) => '~m~16~m~~j~{"foo":"bar"}';

is $conn->build_message('привет') => '~m~6~m~' . encode_utf8('привет');
is $conn->build_message({foo => 'привет'}) => '~m~19~m~~j~{"foo":"'
  . encode_utf8('привет') . '"}';
