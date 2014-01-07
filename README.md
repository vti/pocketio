# NAME

PocketIO - Socket.IO PSGI application

# SYNOPSIS

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

# DESCRIPTION

[PocketIO](http://search.cpan.org/perldoc?PocketIO) is a server implementation of SocketIO in Perl, you still need
`socket.io` javascript library on the client.

[PocketIO](http://search.cpan.org/perldoc?PocketIO) aims to have API as close as possible to the Node.js implementation
and sometimes it might look not very perlish.

## How to use

First you mount [PocketIO](http://search.cpan.org/perldoc?PocketIO) as a normal [Plack](http://search.cpan.org/perldoc?Plack) application. It is recommended
to mount it to the `/socket.io` path since that will not require any changes on
the client side.

When the client is connected your handler is called with a [PocketIO::Socket](http://search.cpan.org/perldoc?PocketIO::Socket)
object as a first parameter.

## Sending and receiving messages

A simple echo handler can look like this:

    sub {
        my $self = shift;

        $self->on('message' => sub {
            my $self = shift;
            my ($message) = @_;

            $self->send($message);
        });
    }

## Sending and receiving events

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

## Broadcasting and sending messages/events to everybody

Broadcasting is sending messages to everybody except you:

    $self->broadcast->send('foo');
    $self->broadcast->emit('foo');

Method `sockets` represents all connected clients:

    $self->sockets->send('foo');
    $self->sockets->emit('foo');

## Acknowlegements

Sometimes you want to know when the client received a message or event. In order
to achieve this just pass a callback as the last parameter:

    $self->send('foo', sub {'client got message'});
    $self->emit('foo', sub {'client got event'});

## Storing data in the socket object

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

## Namespacing

Not implemented yet.

## Volatile messages

Not implemented yet.

## Rooms

A room is a named group of connections for more fine-grained
broadcasts.  You can subscribe or unsubscribe a socket to/from a room:

    sub {
        my $self = shift;

        $self->join('a room');

        $self->sockets->in('a room')->emit('message', data);
        $self->broadcast->to('a room')->emit("other message");
    }

# CONFIGURATIONS

- handler

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
- class or instance, method

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

    Loads `class`, creates a new object or uses a passed `instance` and runs
    `run` method expecting it to return an anonymous subroutine.

# TLS/SSL

For TLS/SSL a secure proxy is needed. `stunnel` or [App::TLSMe](http://search.cpan.org/perldoc?App::TLSMe) are
recommended.

# SCALING

See [PocketIO::Pool::Redis](http://search.cpan.org/perldoc?PocketIO::Pool::Redis).

# DEBUGGING

Use `POCKETIO_DEBUG` and `POCKETIO_CONNECTION_DEBUG` variables for debugging.

# METHODS

## `new`

Create a new [PocketIO](http://search.cpan.org/perldoc?PocketIO) instance.

## `pool`

Holds [PocketIO::Pool](http://search.cpan.org/perldoc?PocketIO::Pool) object by default.

## `call`

For Plack apps compatibility.

## `to_app`

Returns PSGI code reference.

# SEE ALSO

More information about SocketIO you can find on the website [http://socket.io/](http://socket.io/), or
on the GitHub [https://github.com/LearnBoost/Socket.IO](https://github.com/LearnBoost/Socket.IO).

[Protocol::SocketIO](http://search.cpan.org/perldoc?Protocol::SocketIO), [PSGI](http://search.cpan.org/perldoc?PSGI)

# DEVELOPMENT

## Repository

    http://github.com/vti/pocketio

# CREDITS

Socket.IO author(s) and contributors.

Jens Gassmann

Uwe Voelker

Oskari Okko Ojala

Jason May

Michael FiG

Peter Stuifzand

tokubass

mvgrimes

# AUTHOR

Viacheslav Tykhanovskyi, `vti@cpan.org`.

# COPYRIGHT AND LICENSE

Copyright (C) 2011-2013, Viacheslav Tykhanovskyi

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.
