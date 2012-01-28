package PocketIO;

use strict;
use warnings;

our $VERSION = '0.13';

use overload '&{}' => sub { shift->to_app(@_) }, fallback => 1;

use PocketIO::Exception;
use PocketIO::Resource;
use PocketIO::Pool;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{handler} = $self->_get_handler;

    $self->{socketio} ||= {};

    return $self;
}

sub to_app {
    my $self = shift;

    return sub { $self->call(@_) };
}

sub call {
    my $self = shift;
    my ($env) = @_;

    my $response;
    eval {
        my $dispatcher = $self->_build_dispatcher(%{$self->{socketio}});

        $response = $dispatcher->dispatch($env, $self->{handler});
    } or do {
        my $e = $@;

        require Scalar::Util;
        die $e unless Scalar::Util::blessed($e);

        my $code = $e->code;
        my $message = $e->message || 'Internal Server Error';

        my @headers = (
            'Content-Type'   => 'text/plain',
            'Content-Length' => length($message),
        );

        $response = [$code, \@headers, [$message]];
    };

    return $response;
}

sub pool {
    my $self = shift;

    $self->{pool} ||= PocketIO::Pool->new;

    return $self->{pool};
}

sub _build_dispatcher {
    my $self = shift;

    return PocketIO::Resource->new(pool => $self->pool, @_);
}

sub _get_handler {
    my $self = shift;

    return $self->{handler} if $self->{handler};

    die q{Either 'handler', 'class' or 'instance' must be specified}
      unless $self->{instance} || $self->{class};

    my $method = $self->{method} || 'run';

    my $instance = $self->{instance}
      || do {
        my $class = $self->{class};

        my $path = $class;
        $path =~ s{::}{/}g;
        $path .= '.pm';

        require $path;
        $class->new;
      };

    return $instance->run;
}

1;
__END__

=head1 NAME

PocketIO - Socket.IO PSGI application

=head1 SYNOPSIS

    use Plack::Builder;

    builder {
        mount '/socket.io' => PocketIO->new(
            handler => sub {
                my $self = shift;

                $self->on(
                    'message' => sub {
                        my $self = shift;
                        my ($message) = @_;

                        ...;
                    }
                );

                $self->send({buffer => []});
            }
        );

        $app;
    };

    # or

    builder {
        mount '/socket.io' =>
          PocketIO->new(class => 'MyApp::Handler', method => 'run');

        $app;
    };

=head1 DESCRIPTION

L<PocketIO> is a server implementation of SocketIO in Perl, you still need
C<socket.io> javascript library on the client.

L<PocketIO> aims to have API as close as possible to the Node.js implementation
and sometimes it might look not very perlish.

=head2 How to use

First you mount L<PocketIO> as a normal L<Plack> application. It is recommended
to mount it to the C</socket.io> path since that will not require any changes on
the client side.

When the client is connected your handler is called with a L<PocketIO::Socket>
object as a first parameter.

=head2 Sending and receiving messages

A simple echo handler can look like this:

    sub {
        my $self = shift;

        $self->on('message' => sub {
            my $self = shift;
            my ($message) = @_;

            $self->send($message);
        });
    }

=head2 Sending and receiving events

Events are special messages that behave like rpc calls.

    sub {
        my $self = shift;

        $self->on('username' => sub {
            my $self = shift;
            my ($nick) = @_;

            ...
        });

        $self->emit('username', 'vti');
    }

=head2 Broadcasting and sending messages/events to everybody

Broadcasting is sending messages to everybody except you:

    $self->broadcast->send('foo');
    $self->broadcast->emit('foo');

Method C<sockets> represents all connected clients:

    $self->sockets->send('foo');
    $self->sockets->emit('foo');

=head2 Acknowlegements

Sometimes you want to know when the client received a message or event. In order
to achieve this just pass a callback as the last parameter:

    $self->send('foo', sub {'client got message'});
    $self->emit('foo', sub {'client got event'});

=head2 Storing data in the socket object

Often it is required to store some data in the client object. Instead of using
global variables there are two handy methods:

    sub {
        my $self = shift;

        $self->set(foo => 'bar', sub { 'ready' });
        $self->get('foo' => sub {
            my $self = shift;
            my ($err, $foo) = @_;
        });
    }

=head2 Namespacing

Not implemented yet.

=head2 Volatile messages

Not implemented yet.

=head2 Rooms

Not implemented yet.

=head1 CONFIGURATIONS

=over 4

=item handler

    PocketIO->new(
        handler => sub {
            my $socket = shift;

            $socket->on(
                'message' => sub {
                    my $socket = shift;
                }
            );

            $socket->send('hello');
        }
    );

=item class or instance, method

    PocketIO->new(class => 'MyHandler', method => 'run');

    # or

    PocketIO->new(instance => MyHandler->new(foo => 'bar'), method => 'run');

    package MyHandler;

    sub new { ...  } # or use Moose, Boose, Goose, Doose

    sub run {
        my $self = shift;

        return sub {

            # same code as above
        }
    }

Loads C<class>, creates a new object or uses a passed C<instance> and runs
C<run> method expecting it to return an anonymous subroutine.

=back

=head1 TLS/SSL

For TLS/SSL a secure proxy is needed. C<stunnel> or L<App::TLSMe> are
recommended.

=head1 SCALING

See L<PocketIO::Pool::Redis>.

=head1 DEBUGGING

Use C<POCKETIO_DEBUG> and C<POCKETIO_CONNECTION_DEBUG> variables for debugging.

=head1 METHODS

=head2 C<new>

Create a new L<PocketIO> instance.

=head2 C<pool>

Holds L<PocketIO::Pool> object by default.

=head2 C<call>

For Plack apps compatibility.

=head2 C<to_app>

Returns PSGI code reference.

=head1 SEE ALSO

More information about SocketIO you can find on the website L<http://socket.io/>, or
on the GitHub L<https://github.com/LearnBoost/Socket.IO>.

L<Protocol::SocketIO>, L<PSGI>

=head1 DEVELOPMENT

=head2 Repository

    http://github.com/vti/pocketio

=head1 CREDITS

Socket.IO author(s) and contributors.

Jens Gassmann

Uwe Voelker

Oskari Okko Ojala

=head1 AUTHOR

Viacheslav Tykhanovskyi, C<vti@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011-2012, Viacheslav Tykhanovskyi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=cut
