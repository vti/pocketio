package PocketIO::Transport::Htmlfile;

use strict;
use warnings;

use base 'PocketIO::Transport::Base';

use HTTP::Body;
use PocketIO::Response::Chunked;

sub name {'htmlfile'}

sub dispatch {
    my $self = shift;
    my ($cb) = @_;

    my $req  = $self->req;
    my $name = $self->name;

    if ($req->method eq 'GET') {
        return $self->_dispatch_stream($cb) if $req->path =~ m{^/$name//\d+$};
    }

    return
      unless $req->method eq 'POST'
          && $req->path_info =~ m{^/$name/(\d+)/send$};

    return $self->_dispatch_send($req, $1);
}

sub _dispatch_stream {
    my $self = shift;
    my ($cb) = @_;

    my $handle = $self->_build_handle($self->env->{'psgix.io'});

    return sub {
        my $conn = $self->add_connection(on_connect => $cb);

        my $close_cb = sub { $handle->close; $self->client_disconnected($conn); };
        $handle->on_eof($close_cb);
        $handle->on_error($close_cb);

        $handle->on_heartbeat(sub { $conn->send_heartbeat });

        my $id = $self->_wrap_into_script($conn->build_id_message);

        $handle->write(
            join "\x0d\x0a" => 'HTTP/1.1 200 OK',
            'Content-Type: text/html',
            'Connection: keep-alive',
            'Transfer-Encoding: chunked',
            '',
            sprintf('%x', 244 + 12),
            '<html><body>' . (' ' x 244),
            sprintf('%x', length($id)),
            $id,
            ''
        );

        $conn->on_write(
            sub {
                my $conn = shift;
                my ($message) = @_;

                $message = $self->_wrap_into_script($message);

                $handle->write(
                    join "\x0d\x0a" => sprintf('%x', length($message)),
                    $message,
                    ''
                );
            }
        );

        $self->client_connected($conn);
    };
}

sub _dispatch_send {
    my $self = shift;
    my ($req, $id) = @_;

    my $conn = $self->find_connection($id);
    return unless $conn;

    my $raw_body = $req->content;
    my $zeros = $raw_body =~ s/\0//g;

    my $body = HTTP::Body->new($self->env->{CONTENT_TYPE},
        $self->env->{CONTENT_LENGTH} - $zeros);
    $body->add($raw_body);

    my $data = $body->param->{data};

    $conn->read($data);

    return PocketIO::Response::Chunked->finalize;
}

sub _wrap_into_script {
    my $self = shift;
    my ($message) = @_;

    $message =~ s/"/\\"/g;
    return qq{<script>parent.s._("$message", document);</script>};
}

1;
__END__

=head1 NAME

PocketIO::Htmlfile - Htmlfile transport

=head1 DESCRIPTION

L<PocketIO::Htmlfile> is a C<htmlfile> transport
implementation.

=cut
