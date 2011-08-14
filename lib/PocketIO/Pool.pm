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

    return $self;
}

sub find_connection {
    my $self = shift;
    my ($conn) = @_;

    my $id = blessed $conn ? $conn->id : $conn;

    return $self->{connections}->{$id};
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

    DEBUG && warn "Removed connection '" . $id . "'\n";

    return $cb->() if $cb;
}

sub send {
    my $self = shift;

    foreach my $conn ($self->_connections) {
        next unless $conn->is_connected;

        $conn->socket->send(@_);
    }

    return $self;
}

sub broadcast {
    my $self    = shift;
    my $invoker = shift;

    foreach my $conn ($self->_connections) {
        next unless $conn->is_connected;
        next if $conn->id eq $invoker->id;

        $conn->socket->send(@_);
    }

    return $self;
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

=cut
