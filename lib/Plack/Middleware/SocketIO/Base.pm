package Plack::Middleware::SocketIO::Base;

use strict;
use warnings;

use JSON   ();
use Encode ();
use Try::Tiny;
use Scalar::Util qw(weaken);

use Plack::Request;
use Plack::Middleware::SocketIO::Handle;
use Plack::Middleware::SocketIO::Resource;

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;

    weaken $self->{env};
    $self->{req} = Plack::Request->new($self->{env});

    return $self;
}

sub req { shift->{req} }
sub env { shift->{req}->{env} }

sub resource {
    my $self = shift;
    my ($resource) = @_;

    return $self->{resource} unless defined $resource;

    $self->{resource} = $resource;

    return $self;
}

sub add_connection {
    my $self = shift;

    return Plack::Middleware::SocketIO::Resource->instance->add_connection(
        type => $self->name,
        @_
    );
}

sub remove_connection {
    my $self = shift;
    my ($conn) = @_;

    Plack::Middleware::SocketIO::Resource->instance->remove_connection(
        $conn->id);

    return $self;
}

sub find_connection_by_id {
    my $self = shift;
    my ($id) = @_;

    return Plack::Middleware::SocketIO::Resource->instance->connection($id);
}

sub client_connected {
    my $self = shift;
    my ($conn) = @_;

    return if $conn->is_connected;

    $self->_log_client_connected($conn);

    $conn->connect;
}

sub client_disconnected {
    my $self = shift;
    my ($conn) = @_;

    $conn->disconnect;

    $self->_log_client_disconnected($conn);

    $self->remove_connection($conn);
}

sub _log_client_connected {
    my $self = shift;
    my ($conn) = @_;

    my $logger = $self->_get_logger;
    return unless $logger;

    $logger->(
        {   level   => 'debug',
            message => sprintf(
                "Client '%s' connected via '%s'",
                $conn->id, $conn->type
            )
        }
    );
}

sub _log_client_disconnected {
    my $self = shift;
    my ($conn) = @_;

    my $logger = $self->_get_logger;
    return unless $logger;

    $logger->(
        {   level   => 'debug',
            message => sprintf("Client '%s' disconnected", $conn->id)
        }
    );
}

sub _get_logger {
    my $self = shift;

    return $self->env->{'psgix.logger'};
}

sub _build_handle {
    my $self = shift;

    return Plack::Middleware::SocketIO::Handle->new(@_);
}

1;
__END__

=head1 NAME

Plack::Middleware::SocketIO::Base - Base class for transports

=head1 DESCRIPTION

L<Plack::Middleware::SocketIO::Base> is a base class for the transports.

=head1 METHODS

=head2 C<new>

=head2 C<env>

=head2 C<req>

=head2 C<resource>

=head2 C<add_connection>

=head2 C<remove_connection>

=head2 C<find_connection_by_id>

=head2 C<client_connected>

=head2 C<client_disconnected>

=cut
