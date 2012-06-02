package PocketIO::Sockets;

use strict;
use warnings;

use PocketIO::Message;
use PocketIO::Room;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub send {
    my $self = shift;

    $self->{pool}->send(@_);

    return $self;
}

sub emit {
    my $self = shift;
    my $name = shift;

    my $event = $self->_build_event_message($name, @_);

    $self->{pool}->send($event);

    return $self;
}

sub in {
    my $self = shift;
    my ($room) = @_;

    return PocketIO::Room->new(room => $room, pool => $self->{pool});
}

sub _build_event_message {
    my $self  = shift;
    my $event = shift;

    return PocketIO::Message->new(
        type => 'event',
        data => {name => $event, args => [@_]}
    );
}

1;
__END__

=head1 NAME

PocketIO::Sockets - Sockets class

=head1 DESCRIPTION

Used to send messages to B<all> clients.

=head1 METHODS

=head2 C<new>

Create new instance.

=head2 C<send>

Send message.

=head2 C<emit>

Emit event.

=cut
