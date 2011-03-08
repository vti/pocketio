use strict;
use warnings;

use lib 't/lib';

BEGIN { $ENV{TEST_TRANSPORT} = 'xhr-multipart' }

use Test::More;

plan skip_all => 'set TEST_LIVE to run this test' unless $ENV{TEST_LIVE};
plan tests => 3;

use AnyEvent::Impl::Perl;
use AnyEvent::HTTP;
use Utils;

my $id;
my $buffer = '';

my $stream;
$stream = my_http_get_raw "/", sub {
    my $chunk = shift;

    $buffer .= $chunk;

    if ($buffer
        =~ qr{Content-Type: multipart/x-mixed-replace;boundary="socketio"}ms
        && $buffer =~ m/~m~16~m~(\d+)/ms)
    {
        $id = $1;

        like $id => qr/(\d+)/;

        http_post my_build_url("/$id/send"), "data=~m~5~m~hello", sub {
              my $res = shift;

              is $res => 'ok';

              $stream->send;
          };
    }
};

$stream->recv;
