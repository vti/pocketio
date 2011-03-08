use strict;
use warnings;

use lib 't/lib';

BEGIN { $ENV{TEST_TRANSPORT} = 'websocket' }

use Test::More;

plan skip_all => 'set TEST_LIVE to run this test' unless $ENV{TEST_LIVE};
plan tests => 1;

use Protocol::WebSocket::Handshake::Client;
use Protocol::WebSocket::Frame;
use AnyEvent::Impl::Perl;
use AnyEvent::Socket;
use Utils;

my $hs =
  Protocol::WebSocket::Handshake::Client->new(url =>
      "ws://$ENV{TEST_HOST}:$ENV{TEST_PORT}/$ENV{TEST_RESOURCE}/$ENV{TEST_TRANSPORT}"
  );
my $frame = Protocol::WebSocket::Frame->new;

my $cv = AnyEvent->condvar;

tcp_connect $ENV{TEST_HOST}, $ENV{TEST_PORT}, sub {
    my ($fh) = @_ or return $cv->send;

    syswrite $fh, $hs->to_string;

    my $read_watcher;
    $read_watcher = AnyEvent->io(
        fh   => $fh,
        poll => "r",
        cb   => sub {
            my $len = sysread $fh, my $chunk, 1024, 0;

            $hs->parse($chunk) unless $hs->is_done;

            if ($hs->is_done) {
                $frame->append($chunk);

                if (my $message = $frame->next) {
                    like $message => qr/~m~16~m~\d+/;
                    $cv->send;
                }
            }

            if ($len <= 0) {
                undef $read_watcher;
                $cv->send;
            }
        }
    );
};

$cv->recv;
