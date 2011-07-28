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

sub connections {
    my $self = shift;

    return values %{$self->{connections}};
}

sub add_connection {
    my $self = shift;

    my $conn = $self->_build_connection(@_);

    $self->{connections}->{$conn->id} = $conn;

    DEBUG && warn "Added connection '" . $conn->id . "'\n";

    return $conn;
}

sub remove_connection {
    my $self = shift;

    my $id = blessed $_[0] ? $_[0]->id : $_[0];

    delete $self->{connections}->{$id};

    DEBUG && warn "Removed connection '" . $id . "'\n";
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
