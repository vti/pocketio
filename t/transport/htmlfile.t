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

        my $session_id = http_get_session_id $server, $port;

        my $cv = AnyEvent->condvar;
        $cv->begin;

        tcp_connect $server, $port, sub {
            my ($fh) = @_ or return $cv->send;

            syswrite $fh,
              join "\x0d\x0a" =>
              "GET /socket.io/1/htmlfile/$session_id HTTP/1.0",
              "Host: $server:$port",
              'Connection: keep-alive',
              '',
              '';

            my $buffer = '';

            my $read_watcher;
            $read_watcher = AnyEvent->io(
                fh   => $fh,
                poll => "r",
                cb   => sub {
                    my $len = sysread $fh, my $chunk, 1024, 0;

                    $buffer .= $chunk;

                    if ($buffer
                        =~ m!\Q<html><body><script>var _ = function (msg) { parent.s._(msg, document); };</script>\E!
                        && $buffer =~ m!\Q<script>_("1::");</script>\E!)
                    {
                        undef $read_watcher;
                        $cv->end;
                    }

                    if ($len <= 0) {
                        undef $read_watcher;
                        $cv->end;
                    }
                }
            );

            $cv->begin;
            tcp_connect $server, $port, sub {
                my ($fh) = @_ or return $cv->send;

                syswrite $fh,
                  join "\x0d\x0a" =>
                  "POST /socket.io/1/htmlfile/$session_id HTTP/1.0",
                  "Host: $server:$port",
                  'Content-Length: 3',
                  '',
                  '2::';

                my $read_watcher;
                $read_watcher = AnyEvent->io(
                    fh   => $fh,
                    poll => "r",
                    cb   => sub {
                        my $len = sysread $fh, my $chunk, 1024, 0;

                        if ($chunk =~ m/1$/) {
                            ok(1);
                            $cv->end;
                        }

                        if ($len <= 0) {
                            undef $read_watcher;
                            $cv->end;
                        }
                    }
                );
            };
        };

        $cv->wait;
    }
);
