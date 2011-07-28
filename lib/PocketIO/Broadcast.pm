package PocketIO::Broadcast;

use strict;
use warnings;

use base 'PocketIO::Sockets';

sub send {
    my $self = shift;

    $self->{pool}->broadcast(@_);

    return $self;
}

sub emit {
    my $self = shift;
    my $name = shift;

    my $event = $self->_build_event_message($name, @_);

    $self->{pool}->broadcast($self->{conn}, $event);

    return $self;
}

1;
