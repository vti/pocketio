use strict;
use warnings;

use Test::More tests => 2;
use PocketIO::Test;

use AnyEvent;
use AnyEvent::Impl::Perl;
use AnyEvent::Socket;
use AnyEvent::HTTP;
use Plack::Builder;
use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Client;

use PocketIO;

my $app = builder {
    mount '/socket.io' => PocketIO->new(
        handler => sub {
            my $self = shift;

            ok(1);
        }
    );
};

my $server = '127.0.0.1';

test_pocketio(
    $app => sub {
        my $port = shift;

        my $session_id = http_get_session_id "http://$server:$port/socket.io/1/";

        my $cv = AnyEvent->condvar;

        $cv->begin;
        tcp_connect $server, $port, sub {
            my ($fh) = @_ or return $cv->send;

            my $hs = Protocol::WebSocket::Handshake::Client->new(url =>
                  "ws://$server:$port/socket.io/1/websocket/$session_id");
            my $frame = Protocol::WebSocket::Frame->new;

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
                            is $message, '1::';
                            $cv->end;
                        }
                    }

                    if ($len <= 0) {
                        undef $read_watcher;
                        $cv->end;
                    }
                }
            );
        };

        $cv->wait;
    }
);
