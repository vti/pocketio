package Plack::Middleware::SocketIO::XHRMultipart;

use strict;
use warnings;

use base 'Plack::Middleware::SocketIO::Base';

use Plack::Request;
use Plack::Middleware::SocketIO::Impl;

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{boundary} ||= 'socketio';

    return $self;
}

sub name {'xhr-multipart'}

sub finalize {
    my $self = shift;
    my ($env, $cb) = @_;

    my $req = Plack::Request->new($env);

    if ($req->method eq 'GET') {
        return $self->_new_connection($cb);
    }

    my $path = $req->path_info;
    my ($id) = $path =~ m{/xhr-multipart/(\d+)/send};

    if ($req->method ne 'POST' || !$id) {
        return [400, [], ['Bad request']];
    }

    return $self->_new_message($id, $req);
}

sub _new_connection {
    my $self = shift;
    my ($cb) = @_;

    return sub {
        my $respond = shift;

        my $boundary = $self->{boundary};

        my $h = $self->handle;

        $h->write(
            join "\x0d\x0a" => 'HTTP/1.1 200 OK',
            qq{Content-Type: multipart/x-mixed-replace;boundary="$boundary"},
            'Connection: keep-alive', '', ''
        );

        $h->on_read(
            sub {
                warn "$_[0]";
            }
        );

        $h->heartbeat_timeout(10);
        $h->on_heartbeat(sub { $self->send_heartbeat });

        my $conn =
          Plack::Middleware::SocketIO::Impl->instance->add_connection(
            transport => $self);

        $self->id($conn->id);
        $self->send_message($conn->id);

        $cb->($self);
    };
}

sub _new_message {
    my $self = shift;
    my ($id, $req) = @_;

    my $instance = Plack::Middleware::SocketIO::Impl->instance;

    my $conn = $instance->connection($id);

    return [400, [], ['Bad request']] unless $conn;

    my $retval = [
        200,
        ['Content-Type' => 'text/plain', 'Transfer-Encoding' => 'chunked'],
        ["2\x0d\x0aok\x0d\x0a" . "0\x0d\x0a\x0d\x0a"]
    ];

    my $data = $req->body_parameters->get('data');

    $conn->transport->read($data);

    return $retval;
}

sub _format_message {
    my $self = shift;
    my ($message) = @_;

    my $boundary = $self->{boundary};

    my $string = '';

    $string .= "Content-Type: text/plain\x0a\x0a";
    if ($message eq '') {
        $string .= "-1--$boundary--\x0a";
    }
    else {
        $string .= "$message\x0a--$boundary\x0a";
    }

    return $string;
}

1;
