package PocketIO::Transport::BasePolling;

use strict;
use warnings;

use base 'PocketIO::Transport::Base';

sub dispatch {
    my $self = shift;
    my ($cb) = @_;

    my $req  = $self->req;
    my $name = $self->name;

    PocketIO::Exception->throw(400 => 'Wrong path')
      unless $req->path =~ m{^/\d+/$name/(\d+)/?$};

    if ($req->method eq 'GET') {
        return $self->_dispatch_stream($1);
    }

    return $self->_dispatch_send($1);
}

sub _dispatch_stream {
    my $self = shift;
    my ($id) = @_;

    my $conn = $self->find_connection($id);

    my $handle = $self->_build_handle(fh => $self->env->{'psgix.io'});

    return sub {
        my $respond = shift;

        my $close_cb =
          sub { $handle->close; $self->client_disconnected($conn); };
        $handle->on_eof($close_cb);
        $handle->on_error($close_cb);

        $handle->on_heartbeat(sub { $conn->send_heartbeat });

        if ($conn->has_staged_messages) {
            $self->_write($conn, $handle, $conn->staged_message);
        }
        else {
            $conn->on(
                write => sub {
                    my $conn = shift;
                    my ($message) = @_;

                    $conn->on(write => undef);
                    $self->_write($conn, $handle, $message);
                }
            );
        }

        $conn->on(close => $close_cb);

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
    my ($id) = @_;

    my $conn = $self->find_connection($id);

    my $data = $self->_get_content;

    $conn->parse_message($data);

    return [200, ['Content-Length' => 1], ['1']];
}

sub _get_content { $_[0]->req->content }

sub _content_type {'text/plain'}

sub _write {
    my $self = shift;
    my ($conn, $handle, $message) = @_;

    $message = $self->_format_message($message);

    $handle->write(
        join(
            "\x0d\x0a" => 'HTTP/1.1 200 OK',
            'Content-Type: ' . $self->_content_type,
            'Content-Length: ' . length($message),
            'Access-Control-Allow-Origin: *',
            'Access-Control-Allow-Credentials: *',
            '', $message,
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

Basic class for polling transports.

=head1 METHODS

=head2 name

=head2 dispatch

=cut
