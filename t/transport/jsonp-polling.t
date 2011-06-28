use strict;
use warnings;

use Test::More tests => 3;
use PocketIO::Test;

use AnyEvent;
use AnyEvent::Impl::Perl;
use AnyEvent::HTTP;
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

        my $session_id = http_get_session_id "http://$server:$port/socket.io/1/";

        my $cv = AnyEvent->condvar;
        $cv->begin;
        http_get "http://$server:$port/socket.io/1/jsonp-polling/$session_id", sub {
            my ($body, $hrd) = @_;

            is $body => 'io.j[0]("1::");';

            $cv->end;
        };

        $cv->begin;
        http_post
          "http://$server:$port/socket.io/1/jsonp-polling/$session_id",
          'd=2%3A%3A',
          headers => {'Content-Type' => 'application/x-www-form-urlencoded'},
          sub {
            my ($body, $hrd) = @_;

            is $body => '1';

            $cv->end;
          };

        $cv->wait;
    }
);
