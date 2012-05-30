package PocketIO::Socket;

use strict;
use warnings;

use PocketIO::Message;

# DEPRECATED
sub send_message          {&send}
sub send_broadcast        { shift->broadcast->send(@_) }
sub send_broadcast_to_all { shift->sockets->send(@_) }
sub emit_broadcast        { shift->broadcast->emit(@_) }
sub emit_broadcast_to_all { shift->sockets->emit(@_) }

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{data} ||= {};

    return $self;
}

sub session_id {&id}
sub id         { $_[0]->{conn}->id }

sub set {
    my $self = shift;
    my ($key, $value, $cb) = @_;

    $self->{data}->{$key} = $value;
    $cb->($self) if $cb;

    return $self;
}

sub get {
    my $self = shift;
    my ($key, $cb) = @_;

    my $value = $self->{data}->{$key};

    $cb->($self, undef, $value);

    return $self;
}

sub on {
    my $self  = shift;
    my $event = shift;

    my $name = "on_$event";

    unless (@_) {
        return $self->{$name};
    }

    $self->{$name} = $_[0];

    return $self;
}

sub emit {
    my $self  = shift;
    my $event = shift;

    $event = $self->_build_event_message($event, @_);

    $self->send($event);

    return $self;
}

sub send {
    my $self = shift;

    $self->{conn}->send(@_);

    return $self;
}

sub broadcast {
    my $self = shift;

    return $self->{conn}->broadcast(@_);
}

sub sockets {
    my $self = shift;

    return $self->{conn}->sockets(@_);
}

sub close {
    my $self = shift;

    $self->{conn}->close;

    return $self;
}

sub _build_event_message {
    my $self  = shift;
    my $event = shift;

    return PocketIO::Message->new(
        type => 'event',
        data => {name => $event, args => [@_]}
    );
}


sub join {
    my $self = shift;
    my $room = shift;

    return $self->{conn}->pool->room_join($room, $self->{conn});
}


sub leave {
    my $self = shift;
    my $room = shift;

    return $self->{conn}->pool->room_leave($room, $self->{conn});
}


1;
__END__

=head1 NAME

PocketIO::Socket - Socket class

=head1 DESCRIPTION

Instance of L<PocketIO::Socket> is actually the object that you get in a
handler.

    builder {
        mount '/socket.io' => PocketIO->new(
            handler => sub {
                my $socket = shift;

                # $socket is PocketIO::Socket instance
            }
        );

        ...
    };

=head1 METHODS

=head2 C<new>

Create new instance.

=head2 C<close>

Close connection.

=head2 C<emit>

Emit event.

=head2 C<get>

Get attribute.

=head2 C<set>

Set atribute.

=head2 C<id>

Get session id.

=head2 C<session_id>

Same as C<id>.

=head2 C<on>

Register event.

=head2 C<send>

Send message.

=head2 C<sockets>

Get sockets object.

=head2 C<broadcast>

Get broadcasting object.

=head2 C<join>

Join the specified room.

=head2 C<leave>

Leave the specified room.

=cut
