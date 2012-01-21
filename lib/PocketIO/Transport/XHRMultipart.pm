package PocketIO::Transport::XHRMultipart;

use strict;
use warnings;

use base 'PocketIO::Transport::Base';

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{boundary} ||= 'socketio';

    return $self;
}

sub dispatch {
    my $self = shift;

    if ($self->{env}->{REQUEST_METHOD} eq 'GET') {
        return $self->_dispatch_stream;
    }

    return $self->_dispatch_send;
}

sub _dispatch_stream {
    my $self = shift;

    return sub {
        my $respond = shift;

        my $handle = $self->{handle};

        my $conn = $self->conn;

        my $close_cb = sub { $handle->close; $self->client_disconnected($conn); };
        $handle->on_eof($close_cb);
        $handle->on_error($close_cb);

        my $boundary = $self->{boundary};

        $conn->on(write =>
            sub {
                my $self = shift;
                my ($message) = @_;

                my $string = '';

                $string .= "Content-Type: text/plain\x0a\x0a";
                if ($message eq '') {
                    $string .= "-1--$boundary--\x0a";
                }
                else {
                    $string .= "$message\x0a--$boundary\x0a";
                }

                $handle->write($string);
            }
        );

        $handle->on_heartbeat(sub { $conn->send_heartbeat });

        $handle->write(
            join "\x0d\x0a" => 'HTTP/1.1 200 OK',
            qq{Content-Type: multipart/x-mixed-replace;boundary="$boundary"},
            'Access-Control-Allow-Origin: *',
            'Access-Control-Allow-Credentials: *',
            'Connection: keep-alive', '', ''
        );

        $self->client_connected($conn);
    };
}

sub _dispatch_send {
    my $self = shift;

    #my $data = $req->body_parameters->get('data');

    #$self->conn->read($data);

    return [200, ['Content-Length' => 1], ['1']];
}

1;
__END__

=head1 NAME

PocketIO::Transport::XHRMultipart - XHRMultipart transport

=head1 DESCRIPTION

L<PocketIO::Transport::XHRMultipart> is a C<xhr-multipart> transport implementation.

=head1 METHODS

=head2 C<new>

=head2 C<dispatch>

=cut
