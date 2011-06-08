package PocketIO::Transport::WebSocket;

use strict;
use warnings;

use base 'PocketIO::Transport::Base';

use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Server;

use PocketIO::Handle;

sub name {'websocket'}

sub dispatch {
    my $self = shift;
    my ($cb) = @_;

    my $fh = $self->req->env->{'psgix.io'};
    return unless $fh;

    my $hs = Protocol::WebSocket::Handshake::Server->new_from_psgi($self->req->env);
    return unless $hs->parse($fh);

    return unless $hs->is_done;

    my $handle = $self->_build_handle($fh);
    my $frame = Protocol::WebSocket::Frame->new;

    return sub {
        my $respond = shift;

        $handle->write(
            $hs->to_string => sub {
                my $handle = shift;

                my $conn = $self->add_connection(on_connect => $cb);

                my $close_cb = sub {
                    $handle->close;
                    $self->client_disconnected($conn);
                };
                $handle->on_eof($close_cb);
                $handle->on_error($close_cb);

                $handle->on_heartbeat(sub { $conn->send_heartbeat });

                $handle->on_read(
                    sub {
                        $frame->append($_[1]);

                        while (my $message = $frame->next_bytes) {
                            $conn->read($message);
                        }
                    }
                );

                $conn->on_write(
                    sub {
                        my $bytes = $self->_build_frame($_[1]);

                        $handle->write($bytes);
                    }
                );

                $self->client_connected($conn);

                $conn->send_id_message($conn->id);
            }
        );
    };
}

sub _build_frame {
    my $self = shift;
    my ($bytes) = @_;

    return Protocol::WebSocket::Frame->new($bytes)->to_bytes;
}

1;
__END__

=head1 NAME

PocketIO::WebSocket - WebSocket transport

=head1 DESCRIPTION

L<PocketIO::WebSocket> is a WebSocket transport implementation.

=head1 SEE ALSO

L<Protocol::WebSocket>

=cut
