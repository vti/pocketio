package PocketIO::Transport::Htmlfile;

use strict;
use warnings;

use base 'PocketIO::Transport::Base';

sub dispatch {
    my $self = shift;

    if ($self->{env}->{REQUEST_METHOD} eq 'GET') {
        return $self->_dispatch_stream;
    }

    return $self->_dispatch_send;
}

sub _dispatch_stream {
    my $self = shift;

    my $conn = $self->conn;

    my $handle = $self->{handle};

    return sub {
        my $close_cb =
          sub { $handle->close; $self->client_disconnected($conn); };
        $handle->on_eof($close_cb);
        $handle->on_error($close_cb);

        $handle->on_heartbeat(sub { $conn->send_heartbeat });

        $handle->write(
            join "\x0d\x0a" => 'HTTP/1.1 200 OK',
            'Content-Type: text/html',
            'Connection: keep-alive',
            'Transfer-Encoding: chunked',
            'Access-Control-Allow-Origin: *',
            'Access-Control-Allow-Credentials: *',
            '',
            sprintf('%x', 173 + 83),
            '<html><body><script>var _ = function (msg) { parent.s._(msg, document); };</script>'
              . (' ' x 173),
            ''
        );

        $conn->on(
            write => sub {
                my $conn = shift;
                my ($message) = @_;

                $message = $self->_format_message($message);

                $handle->write(
                    join "\x0d\x0a" => sprintf('%x', length($message)),
                    $message,
                    ''
                );
            }
        );

        $conn->on(close => $close_cb);

        $self->client_connected($conn);
    };
}

sub _dispatch_send {
    my $self = shift;

    my $content_length = $self->{env}->{CONTENT_LENGTH} || 0;
    my $rcount =
      $self->{env}->{'psgi.input'}->read(my $chunk, $content_length);

    PocketIO::Exception->throw(500) unless $rcount == $content_length;

    $self->conn->parse_message($chunk);

    return [200, ['Content-Length' => 1], ['1']];
}

sub _format_message {
    my $self = shift;
    my ($message) = @_;

    $message =~ s/"/\\"/g;
    return qq{<script>_("$message");</script>};
}

1;
__END__

=head1 NAME

PocketIO::Transport::Htmlfile - Htmlfile transport

=head1 DESCRIPTION

L<PocketIO::Transport::Htmlfile> is a C<htmlfile> transport implementation.

=head1 METHODS

=over

=item dispatch

=back

=cut
