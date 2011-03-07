package Plack::Middleware::SocketIO::WebSocket;

use strict;
use warnings;

use base 'Plack::Middleware::SocketIO::Base';

use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Server;

use Plack::Middleware::SocketIO::Handle;

sub name {'websocket'}

sub finalize {
    my $self = shift;
    my ($req, $cb) = @_;

    my $fh = $req->env->{'psgix.io'};
    return unless $fh;

    my $hs = Protocol::WebSocket::Handshake::Server->new_from_psgi($req->env);
    return unless $hs->parse($fh);

    my $frame = Protocol::WebSocket::Frame->new;
    my $handle = $self->_build_handle($fh);

    return sub {
        my $respond = shift;

        $handle->write(
            $hs->to_string => sub {
                my $handle = shift;

                my $conn = $self->add_connection(on_connect => $cb);

                $handle->on_read(
                    sub {
                        my $handle = shift;

                        $frame->append($_[0]);

                        while (my $message = $frame->next) {
                            $conn->read($message);
                        }
                    }
                );

                $conn->on_write(
                    sub {
                        my $conn = shift;
                        my ($message) = @_;

                        $message = $self->_build_frame($message);

                        $handle->write($message);
                    }
                );

                $conn->send_id_message($conn->id);

                $conn->connected unless $conn->is_connected;
            }
        );
    };
}

sub _build_frame {
    my $self = shift;
    my ($message) = @_;

    return Protocol::WebSocket::Frame->new($message)->to_string;
}

sub _build_handle {
    my $self = shift;

    return Plack::Middleware::SocketIO::Handle->new(@_);
}

1;
