package Plack::Middleware::SocketIO::Impl;

use strict;
use warnings;

use Plack::Request;
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

    my $transport;

    if ($env->{PATH_INFO} =~ s{^/xhr-multipart}{}) {
        $transport = Plack::Middleware::SocketIO::XHRMultipart->new;
    }
    elsif ($env->{PATH_INFO} =~ s{^/xhr-polling}{}) {
        $transport = Plack::Middleware::SocketIO::XHRPolling->new;
    }

    return unless $transport;

    my $req = Plack::Request->new($env);

    return $transport->finalize($req, $cb);
}

sub _build_connection {
    my $self = shift;

    return Plack::Middleware::SocketIO::Connection->new(@_);
}

1;
