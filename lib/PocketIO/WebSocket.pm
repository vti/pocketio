package PocketIO::WebSocket;

use strict;
use warnings;

use base 'PocketIO::Base';

use Encode ();

use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Server;

use PocketIO::Handle;

sub name {'websocket'}

sub finalize {
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

                $handle->heartbeat_timeout(10);
                $handle->on_heartbeat(sub { $conn->send_heartbeat });

                $handle->on_read(
                    sub {
                        my $handle = shift;

                        $frame->append($_[0]);

                        while (my $message = $frame->next_bytes) {
                            $conn->read($message);
                        }
                    }
                );

                $handle->on_eof(
                    sub {
                        $handle->close;

                        $self->client_disconnected($conn);
                    }
                );

                $handle->on_error(
                    sub {
                        $self->client_disconnected($conn);

                        $handle->close;
                    }
                );

                $conn->on_write(
                    sub {
                        my $conn = shift;
                        my ($bytes) = @_;

                        $bytes = $self->_build_frame($bytes);

                        $handle->write($bytes);
                    }
                );

                $conn->send_id_message($conn->id);

                $self->client_connected($conn);
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
