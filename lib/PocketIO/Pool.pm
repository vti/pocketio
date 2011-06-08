package PocketIO::Pool;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use PocketIO::Connection;

use constant DEBUG => $ENV{POCKETIO_POOL_DEBUG};

sub find_connection {
    my $self = shift;
    my ($conn) = @_;

    my $id = blessed $conn ? $conn->id : $conn;

    return $self->_instance->{connections}->{$id};
}

sub connections {
    my $self = shift;

    return values %{$self->_instance->{connections}};
}

sub add_connection {
    my $self = shift;

    my $conn = $self->_build_connection(@_);

    $self->_instance->{connections}->{$conn->id} = $conn;

    $conn->connecting;

    DEBUG && warn "Added connection '" . $conn->id . "'\n";

    return $conn;
}

sub remove_connection {
    my $self = shift;

    my $id = blessed $_[0] ? $_[0]->id : $_[0];

    delete $self->_instance->{connections}->{$id};

    DEBUG && warn "Removed connection '" . $id . "'\n";
}

sub _instance {
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

sub _build_connection {
    my $self = shift;

    return PocketIO::Connection->new(@_,
        on_connect_failed => sub { $self->remove_connection(@_) });
}


1;
__END__

=head1 NAME

PocketIO::Pool - Connection pool

=head1 DESCRIPTION

L<PocketIO::Pool> is a singleton connection pool.

=head1 METHODS

=head2 C<find_connection>

=head2 C<add_connection>

=head2 C<remove_connection>

=head2 C<connections>

=cut
