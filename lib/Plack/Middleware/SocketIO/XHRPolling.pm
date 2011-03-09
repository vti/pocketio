package Plack::Middleware::SocketIO::XHRPolling;

use strict;
use warnings;

use base 'Plack::Middleware::SocketIO::Base';

sub name {'xhr-polling'}

sub finalize {
    my $self = shift;
    my ($cb) = @_;

    my $req      = $self->req;
    my $resource = $self->resource;
    my $name     = $self->name;

    if ($req->method eq 'GET') {
        return $self->_finalize_init($cb)
          if $req->path =~ m{^/$resource/$name//\d+$};

        return $self->_finalize_stream($1)
          if $req->path =~ m{^/$resource/$name/(\d+)/\d+$};
    }

    return
      unless $req->method eq 'POST'
          && $req->path_info =~ m{^/$resource/$name/(\d+)/send$};

    return $self->_finalize_send($req, $1);
}

sub _finalize_init {
    my $self = shift;
    my ($cb) = @_;

    my $conn = $self->add_connection(on_connect => $cb);

    my $body = $conn->build_id_message;

    return [
        200,
        [   'Content-Type'   => 'text/plain',
            'Content-Length' => length($body),
            'Connection'     => 'keep-alive'
        ],
        [$body]
    ];
}

sub _finalize_stream {
    my $self = shift;
    my ($id) = @_;

    my $conn = $self->find_connection_by_id($id);
    return unless $conn;

    my $handle = $self->_build_handle($self->env->{'psgix.io'});

    return sub {
        my $respond = shift;

        $handle->on_eof(
            sub {
                $self->client_disconnected($conn);

                $handle->close;
            }
        );

        $handle->heartbeat_timeout(10);
        $handle->on_heartbeat(sub { $conn->send_heartbeat });

        $conn->on_write(
            sub {
                my $self = shift;
                my ($message) = @_;

                $handle->write(
                    join "\x0d\x0a" => 'HTTP/1.1 200 OK',
                    'Content-Type: text/plain',
                    'Content-Length: ' . length($message), '', $message
                );

                # TODO: set reconnect timeout
            }
        );

        $self->client_connected($conn);
    };
}

sub _finalize_send {
    my $self = shift;
    my ($req, $id) = @_;

    my $conn = $self->find_connection_by_id($id);
    return unless $conn;

    my $retval = [
        200,
        [   'Content-Type'      => 'text/plain',
            'Transfer-Encoding' => 'chunked'
        ],
        ["2\x0d\x0aok\x0d\x0a" . "0\x0d\x0a\x0d\x0a"]
    ];

    my $data = $req->body_parameters->get('data');

    $conn->read($data);

    return $retval;
}

1;
