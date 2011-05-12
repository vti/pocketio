use strict;
use warnings;

use lib 't/lib';

use Test::More;

BEGIN {
    plan skip_all => 'set TEST_LIVE to run this test' unless $ENV{TEST_LIVE};
    plan tests => 2;

    $ENV{TEST_TRANSPORT} = 'jsonp-polling';
}

use AnyEvent::Impl::Perl;
use AnyEvent::HTTP;
use Utils;

my $id;

my $init = my_http_get "//1234567890/0", sub {
    my $res = shift;

    ($id) = $res =~ m/io.JSONP\[0\]\._\("~m~16~m~(\d+)"\);/;
};

$init->recv;

like $id => qr/(\d+)/;

my $req1 = my_http_get "/$id/1234567891/0", sub {
    my $res = shift;

    #warn $res;
};

my $req2 = my_http_post "/$id/1234567892/0", 'data=~m~5~m~hello', sub {
    my $res = shift;

    is $res => 'ok';
};

$req1->recv;
$req2->recv;
