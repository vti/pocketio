package PocketIO::Polling;

use strict;
use warnings;

use base 'PocketIO::Base';

sub _finalize_init {
    my $self = shift;
    my ($cb) = @_;

    my $conn;
    $conn = $self->add_connection(
        on_connect         => $cb,
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

sub _finalize_stream {
    my $self = shift;
    my ($id) = @_;

    my $conn = $self->find_connection($id);
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

        $handle->on_error(
            sub {
                $self->client_disconnected($conn);

                $handle->close;
            }
        );

        $handle->heartbeat_timeout(10);
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

sub _finalize_send {
    my $self = shift;
    my ($req, $id) = @_;

    my $conn = $self->find_connection($id);
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
