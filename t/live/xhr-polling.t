use strict;
use warnings;

use lib 't/lib';

BEGIN { $ENV{TEST_TRANSPORT} = 'xhr-polling' }

use Test::More;

plan skip_all => 'set TEST_LIVE to run this test' unless $ENV{TEST_LIVE};
plan tests => 2;

use AnyEvent::Impl::Perl;
use AnyEvent::HTTP;
use Utils;

my $id;

my $init = my_http_get "//1234567890", sub {
    my $res = shift;

    ($id) = $res =~ m/^~m~16~m~(\d+)/;
};

$init->recv;

like $id => qr/(\d+)/;

my $req1 = my_http_get "/$id/1234567891", sub {
    my $res = shift;

    warn $res;
};

my $req2 = my_http_post "/$id/send", 'data=~m~5~m~hello', sub {
    my $res = shift;

    is $res => 'ok';
};

$req1->recv;
$req2->recv;
