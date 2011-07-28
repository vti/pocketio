package PocketIO::Sockets;

use strict;
use warnings;

use PocketIO::Message;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub send {
    my $self = shift;

    foreach my $conn ($self->_connections) {
        next unless $conn->is_connected;

        # Broadcasting counts as a heartbeat
        $conn->_restart_timer('close');

        $conn->socket->send(@_);
    }

    return $self;
}

sub emit {
    my $self = shift;
    my $name = shift;

    my $event = $self->_build_event_message($name, @_);

    foreach my $conn ($self->_connections) {
        next unless $conn->is_connected;

        # Broadcasting counts as a heartbeat
        $conn->_restart_timer('close');

        $conn->write($event);
    }

    return $self;
}

sub _build_event_message {
    my $self = shift;
    my $event = shift;

    return PocketIO::Message->new(
        type => 'event',
        data => {name => $event, args => [@_]}
    )->to_bytes;
}

sub _connections {
    my $self = shift;

    return $self->{pool}->connections;
}

1;
