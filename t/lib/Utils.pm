package Utils;

use strict;
use warnings;

BEGIN {
    $ENV{TEST_HOST}     ||= 'localhost';
    $ENV{TEST_PORT}     ||= 8080;
    $ENV{TEST_RESOURCE} ||= 'socket.io';
    die 'set TEST_TRANSPORT' unless $ENV{TEST_TRANSPORT};
}

use base 'Exporter';

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::HTTP;

our @EXPORT = qw(my_build_url my_http_get my_http_get_raw my_http_post);

sub my_build_url {
    my $path = shift;

    my $base = "http://$ENV{TEST_HOST}:$ENV{TEST_PORT}/$ENV{TEST_RESOURCE}";
    my $transport = $ENV{TEST_TRANSPORT};

    return "$base/$transport$path";
}

sub my_http_req($@);

sub my_http_get($@)  { my_http_req 'GET',  @_ }
sub my_http_post($@) { my_http_req 'POST', @_ }

sub my_http_req($@) {
    my $method = shift;
    my $path   = shift;
    my $cb     = pop @_;

    my $cv = AnyEvent->condvar;

    http_request $method, my_build_url($path), @_, sub {
        $cb->(@_);
        $cv->send;
    };

    return $cv;
}

sub my_http_get_raw($@) {
    my $path = shift;
    my $cb   = pop @_;

    my $cv = AnyEvent->condvar;

    tcp_connect $ENV{TEST_HOST}, $ENV{TEST_PORT}, sub {
        my ($fh) = @_ or return $cv->send;

        syswrite $fh, "GET /$ENV{TEST_RESOURCE}/$ENV{TEST_TRANSPORT}$path HTTP/1.1\015\012";
        syswrite $fh, "Host: $ENV{TEST_HOST}:$ENV{TEST_PORT}\015\012";
        syswrite $fh, "\015\012";

        my $response = '';

        my $read_watcher;
        $read_watcher = AnyEvent->io(
            fh   => $fh,
            poll => "r",
            cb   => sub {
                my $len = sysread $fh, $response, 1024, length $response;

                $cb->($response);

                if ($len <= 0) {

                    undef $read_watcher;
                    $cv->send($response);
                }
            }
        );
    };

    return $cv;
}

1;
