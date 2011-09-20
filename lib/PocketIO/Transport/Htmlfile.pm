package PocketIO::Transport::Htmlfile;

use strict;
use warnings;

use base 'PocketIO::Transport::Base';

sub name {'htmlfile'}

sub dispatch {
    my $self = shift;

    my $req  = $self->req;
    my $name = $self->name;

    return unless $req->path =~ m{^/\d+/$name/(\d+)/?$};

    my $id = $1;

    if ($req->method eq 'GET') {
        return $self->_dispatch_stream($id) ;
    }

    return $self->_dispatch_send($id);
}

sub _dispatch_stream {
    my $self = shift;
    my ($id) = @_;

    my $conn = $self->find_connection($id);
    return unless $conn;

    my $handle = $self->_build_handle(fh => $self->env->{'psgix.io'});

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
            '<html><body><script>var _ = function (msg) { parent.s._(msg, document); };</script>'.
            (' ' x 173),
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
    my ($id) = @_;

    my $conn = $self->find_connection($id);
    return unless $conn;

    my $data = $self->req->content;

    $conn->parse_message($data);

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

PocketIO::Htmlfile - Htmlfile transport

=head1 DESCRIPTION

L<PocketIO::Htmlfile> is a C<htmlfile> transport implementation.

=head1 METHODS

=over

=item name

=item dispatch

=back

=cut
