package Plack::Middleware::SocketIO::Impl;

use strict;
use warnings;

use Plack::Middleware::SocketIO::Connection;
use Plack::Middleware::SocketIO::Handle;
use Plack::Middleware::SocketIO::WebSocket;
use Plack::Middleware::SocketIO::XHRMultipart;
use Plack::Middleware::SocketIO::XHRPolling;

sub instance {
    my $class = shift;

    no strict;

    ${"$class\::_instance"} ||= $class->_new_instance(@_);

    return ${"$class\::_instance"};
}

sub _new_instance {
    my $class = shift;

    my $self = bless {@_}, $class;

    $self->{connections} = {};

    return $self;
}

sub connection {
    my $self = shift;
    my ($id) = @_;

    return $self->{connections}->{$id};
}

sub add_connection {
    my $self = shift;

    my $conn = $self->_build_connection(@_);

    $self->{connections}->{$conn->id} = $conn;

    return $conn;
}

sub finalize {
    my $self = shift;
    my ($env, $cb) = @_;

    return [500, [], []] unless my $io = $env->{'psgix.io'};
    my $handle = $self->_build_handle($env->{'psgix.io'});

    my $path = $env->{PATH_INFO};
    $path = '/' unless defined $path;
    $path = "/$path" unless $path =~ m{^/} || $path eq '/';

    $path =~ s{/socket\.io}{};

    my $transport;
    if ($path =~ m{/xhr-multipart}) {
        $transport =
          Plack::Middleware::SocketIO::XHRMultipart->new(handle => $handle);
    }
    elsif ($path =~ m{/xhr-polling}) {
        #return Plack::Middleware::SocketIO::XHRPolling->new($self->{env})->handshake($cb);
    }

    #return Plack::Middleware::SocketIO::WebSocket->new($self->{env})->handshake($cb);

    if (!$transport) {
        return [400, ['Content-type' => 'text/plain'], ['Bad request']];
    }

    return $transport->finalize($env, $cb);
}

sub _build_connection {
    my $self = shift;

    return Plack::Middleware::SocketIO::Connection->new(@_);
}

sub _build_handle {
    my $self = shift;

    return Plack::Middleware::SocketIO::Handle->new(@_);
}

1;
