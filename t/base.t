use strict;
use warnings;

use Test::More tests => 6;

package Simple;
use base 'Plack::Middleware::SocketIO::Base';

sub send_message {}

package main;

my $base = Simple->new;
ok $base;

my $output = '';
$base->on_message(sub { $output .= $_[1] });

$base->read('~m~4~m~1234');
is $output => '1234';
$output = '';

$base->read('~m~4~m~1234~m~2~m~12');
is $output => '123412';
$output = '';

$base->read('foobar');
is $output => '';

$base->on_message(sub { $output = $_[1] });

$base->read('~m~16~m~~j~{"foo":"bar"}');
is_deeply $output => {foo => 'bar'};
$output = '';

$base->read('~m~16~m~~j~{"foo","bar"}');
is $output => '';
