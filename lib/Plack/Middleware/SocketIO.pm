package Plack::Middleware::SocketIO;

use strict;
use warnings;

use base 'Plack::Middleware';

our $VERSION = '0.00901';

use Plack::Util::Accessor qw(resource handler);

use Plack::Middleware::SocketIO::Resource;

sub call {
    my $self = shift;
    my ($env) = @_;

    my $resource = $self->resource || 'socket.io';
    $resource = quotemeta $resource;

    if ($env->{PATH_INFO} =~ m{^/$resource/}) {
        my $instance = Plack::Middleware::SocketIO::Resource->instance;

        return $instance->finalize($env, $self->handler)
          || [400, ['Content-Type' => 'text/plain'], ['Bad request']];
    }

    return $self->app->($env);
}

1;
__END__

=head1 NAME

Plack::Middleware::SocketIO - Socket.IO middleware

=head1 SYNOPSIS

    use Plack::Builder;

    builder {
        enable "SocketIO", handler => sub {
            my $self = shift;

            $self->on_message(
                sub {
                    my $self = shift;
                    my ($message) = @_;

                    ...
                }
            );

            $self->send_message({buffer => []});
        };

        $app;
    };

=head1 DESCRIPTION

L<Plack::Middleware::SocketIO> is a server implmentation of SocketIO in Perl.

=head2 SocketIO

More information about SocketIO you can find on the website L<http://socket.io/>, or
on the GitHub L<https://github.com/LearnBoost/Socket.IO>.

=head2 Transports

All the transports are supported.

    WebSocket
    Adobe(R) Flash(R) Socket
    AJAX long polling
    AJAX multipart streaming
    Forever Iframe
    JSONP Polling

=head2 TLS/SSL

For TLS/SSL a secure proxy is needed. C<stunnel> or L<App::TLSMe> is
recommended.

=head1 DEVELOPMENT

=head2 Repository

    http://github.com/vti/plack-middleware-socketio

=head1 CREDITS

Socket.IO author(s) and contributors.

=head1 AUTHOR

Viacheslav Tykhanovskyi, C<vti@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011, Viacheslav Tykhanovskyi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
