package PocketIO::Broadcast;

use strict;
use warnings;

use base 'PocketIO::Sockets';

sub _connections {
    my $self = shift;

    my $id = $self->{conn}->id;

    return grep { $_->id ne $id } $self->{pool}->connections;
}

1;
