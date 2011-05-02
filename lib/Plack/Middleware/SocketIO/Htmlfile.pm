package Plack::Middleware::SocketIO::Htmlfile;

use strict;
use warnings;

use base 'Plack::Middleware::SocketIO::Base';

use HTTP::Body;

sub name {'htmlfile'}

sub finalize {
    my $self = shift;
    my ($cb) = @_;

    my $req      = $self->req;
    my $resource = $self->resource;
    my $name     = $self->name;

    if ($req->method eq 'GET') {
        return $self->_finalize_stream($cb)
          if $req->path =~ m{^/$resource/$name//\d+$};
    }

    return
      unless $req->method eq 'POST'
          && $req->path_info =~ m{^/$resource/$name/(\d+)/send$};

    return $self->_finalize_send($req, $1);
}

sub _finalize_stream {
    my $self = shift;
    my ($cb) = @_;

    my $handle = $self->_build_handle($self->env->{'psgix.io'});

    return sub {
        my $conn = $self->add_connection(on_connect => $cb);

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

sub _finalize_send {
    my $self = shift;
    my ($req, $id) = @_;

    my $conn = $self->find_connection_by_id($id);
    return unless $conn;

    my $retval = [
        200,
        [   'Content-Type'      => 'text/plain',
            'Transfer-Encoding' => 'chunked'
        ],
        ["2\x0d\x0aok\x0d\x0a" . "0\x0d\x0a\x0d\x0a"]
    ];

    my $raw_body = $req->content;
    my $zeros = $raw_body =~ s/\0//g;

    my $body = HTTP::Body->new($self->env->{CONTENT_TYPE},
        $self->env->{CONTENT_LENGTH} - $zeros);
    $body->add($raw_body);

    my $data = $body->param->{data};

    $conn->read($data);

    return $retval;
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

Plack::Middleware::SocketIO::Htmlfile - Htmlfile transport

=head1 DESCRIPTION

L<Plack::Middleware::SocketIO::Htmlfile> is a C<htmlfile> transport
implementation.

=cut
