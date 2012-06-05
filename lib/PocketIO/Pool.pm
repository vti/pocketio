package PocketIO::Pool;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use PocketIO::Connection;

use constant DEBUG => $ENV{POCKETIO_POOL_DEBUG};

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{connections} = {};
    $self->{rooms}       = {};
    $self->{revrooms}    = {};

    return $self;
}

sub find_local_connection {
    my $self = shift;
    my ($conn) = @_;

    my $id = blessed $conn ? $conn->id : $conn;

    return $self->{connections}->{$id};
}

sub find_connection {
    my $self = shift;

    return $self->find_local_connection(@_);
}

sub add_connection {
    my $self = shift;
    my $cb   = pop @_;

    my $conn = $self->_build_connection(@_);

    $self->{connections}->{$conn->id} = $conn;

    DEBUG && warn "Added connection '" . $conn->id . "'\n";

    return $cb->($conn);
}

sub remove_connection {
    my $self = shift;
    my ($conn, $cb) = @_;

    my $id = blessed $conn ? $conn->id : $conn;

    delete $self->{connections}->{$id};
    foreach my $room (keys %{$self->{revrooms}{$id}}) {
        delete $self->{rooms}{$room}{$id};
    }
    delete $self->{revrooms}{$id};

    DEBUG && warn "Removed connection '" . $id . "'\n";

    return $cb->() if $cb;
}

sub room_join {
    my $self = shift;
    my $room = shift;
    my $conn = shift;

    my $id   = blessed $conn ? $conn->id : $conn;
    $conn = $self->{connections}->{$id};

    $self->{rooms}{$room}{$id}    = $conn;
    $self->{revrooms}{$id}{$room} = $conn;
    return $conn;
}

sub room_leave {
    my $self       = shift;
    my $room       = shift;
    my $conn       = shift;
    my ($subrooms) = @_;

    my $id = blessed $conn ? $conn->id : $conn;

    if ($subrooms) {
        DEBUG && warn "Deleting '$id' subrooms of '$room'\n";
        foreach my $subroom (keys %{$self->{revrooms}{$id}}) {
            if ($subroom =~ /^\Q$room\E/) {
                delete $self->{rooms}{$subroom}{$id};
                delete $self->{revrooms}{$id}{$subroom};
            }
        }
    }
    else {
        DEBUG && warn "Deleting just '$id' room '$room'\n";
        delete $self->{rooms}{$room}{$id};
        delete $self->{revrooms}{$id}{$room};
    }
    return $conn;
}

sub send_raw {
    my $self = shift;
    my ($msg) = {@_};

    if (defined $msg->{id}) {

        # Message directly to a connection.
        my $conn = $self->find_local_connection($msg->{id});
        if (defined $conn) {

            # Send the message here and now.
            DEBUG && warn "Sending message to $msg->{id}\n";
            $conn->send($msg->{message});
        }
        return $conn;
    }

    my @members =
      defined $msg->{room}
      ? values %{$self->{rooms}{$msg->{room}}}
      : $self->_connections;

    foreach my $conn (@members) {
        next unless blessed $conn && $conn->is_connected;
        next if defined $msg->{invoker} && $conn->id eq $msg->{invoker}->id;

        DEBUG && warn "Sending message to " . $conn->id . "\n";
        $conn->socket->send($msg->{message});
    }

    return $self;
}

sub send {
    my $self = shift;

    return $self->send_raw(message => $_[0]);
}

sub broadcast {
    my $self    = shift;
    my $invoker = shift;

    return $self->send_raw(message => $_[0], invoker => $invoker);
}

sub _connections {
    my $self = shift;

    return values %{$self->{connections}};
}

sub _build_connection {
    my $self = shift;

    return PocketIO::Connection->new(
        @_,
        pool                => $self,
        on_connect_failed   => sub { $self->remove_connection(@_) },
        on_reconnect_failed => sub {
            my $conn = shift;

            $conn->disconnected;

            $self->remove_connection($conn);
        }
    );
}

1;
__END__

=head1 NAME

PocketIO::Pool - Connection pool

=head1 DESCRIPTION

L<PocketIO::Pool> is a connection pool.

=head1 METHODS

=head2 C<new>

=head2 C<find_connection>

=head2 C<add_connection>

=head2 C<remove_connection>

=head2 C<connections>

=head2 C<send>

=head2 C<broadcast>

=cut
