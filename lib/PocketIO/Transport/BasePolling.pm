package PocketIO::Transport::BasePolling;

use strict;
use warnings;

use base 'PocketIO::Transport::Base';

use PocketIO::Response::Chunked;

sub _dispatch_init {
    my $self = shift;
    my ($cb) = @_;

    my $conn;
    $conn = $self->add_connection(
        on_connect          => $cb,
        on_reconnect_failed => sub {
            $self->client_disconnected($conn);
        }
    );

    my $body = $self->_format_message($conn->build_id_message);

    return [
        200,
        [   'Content-Type'   => 'text/plain',
            'Content-Length' => length($body),
            'Connection'     => 'keep-alive'
        ],
        [$body]
    ];
}

sub _dispatch_stream {
    my $self = shift;
    my ($id) = @_;

    my $conn = $self->find_connection($id);
    return unless $conn;

    my $handle = $self->_build_handle($self->env->{'psgix.io'});

    return sub {
        my $respond = shift;

        my $close_cb = sub { $handle->close; $self->client_disconnected($conn); };
        $handle->on_eof($close_cb);
        $handle->on_error($close_cb);

        $handle->on_heartbeat(sub { $conn->send_heartbeat });

        if ($conn->has_staged_messages) {
            $self->_write($conn, $handle, $conn->staged_message);
        }
        else {
            $conn->on_write(
                sub {
                    my $conn = shift;
                    my ($message) = @_;

                    $conn->on_write(undef);
                    $self->_write($conn, $handle, $message);
                }
            );
        }

        if ($conn->is_connected) {
            $conn->reconnected;
        }
        else {
            $self->client_connected($conn);
        }
    };
}

sub _dispatch_send {
    my $self = shift;
    my ($req, $id) = @_;

    my $conn = $self->find_connection($id);
    return unless $conn;

    my $data = $req->body_parameters->get('data');

    $conn->read($data);

    return PocketIO::Response::Chunked->finalize;
}

sub _write {
    my $self = shift;
    my ($conn, $handle, $message) = @_;

    $message = $self->_format_message($message);

    $handle->write(
        join(
            "\x0d\x0a" => 'HTTP/1.1 200 OK',
            'Content-Type: text/plain',
            'Content-Length: ' . length($message), '', $message
        ),
        sub {
            $handle->close;
            $conn->reconnecting;
        }
    );
}

sub _format_message { $_[1] }

1;
__END__

=head1 NAME

PocketIO::Polling - Basic class for polling transports

=head1 DESCRIPTION

=cut
