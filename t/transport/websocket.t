use strict;
use warnings;

BEGIN {
    use Test::More;

    plan skip_all => 'Plack and Twiggy are required to run this test'
      unless eval { require Plack; require Twiggy; 1 };
}

plan tests => 2;

use PocketIO::Test;

use AnyEvent;
use AnyEvent::Impl::Perl;
use AnyEvent::Socket;
use Plack::Builder;
use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Client;

use PocketIO;

my $app = builder {
    mount '/socket.io' => PocketIO->new(
        handler => sub {
            my $self = shift;

            ok(1);

            $self->close;
        }
    );
};

my $server = '127.0.0.1';

test_pocketio(
    $app => sub {
        my $port = shift;

        my $session_id = http_get_session_id $server, $port;

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

                    if ($hs->is_done && length($chunk)) {
                        $frame->append($chunk);

                        if (my $message = $frame->next_bytes) {
                            is $message, '1::';
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
