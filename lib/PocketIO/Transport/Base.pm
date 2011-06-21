package PocketIO::Transport::Base;

use strict;
use warnings;

use JSON   ();
use Encode ();
use Try::Tiny;
use Scalar::Util qw(weaken);

use Plack::Request;
use PocketIO::Handle;
use PocketIO::Pool;

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;

    weaken $self->{env};
    $self->{req} = Plack::Request->new($self->{env});

    return $self;
}

sub req { shift->{req} }
sub env { shift->{req}->{env} }

sub add_connection {
    my $self = shift;

    return PocketIO::Pool->add_connection(type => $self->name, req => $self->{req}, @_);
}

sub remove_connection {
    my $self = shift;

    PocketIO::Pool->remove_connection($_[0]);

    return $self;
}

sub find_connection {
    my $self = shift;

    return PocketIO::Pool->find_connection(@_);
}

sub client_connected {
    my $self = shift;
    my ($conn) = @_;

    return if $conn->is_connected;

    $self->_log_client_connected($conn);

    $conn->connected;
}

sub client_disconnected {
    my $self = shift;
    my ($conn) = @_;

    $self->_log_client_disconnected($conn);

    $conn->disconnected;

    $self->remove_connection($conn);

    return $self;
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

    return PocketIO::Handle->new(@_);
}

1;
__END__

=head1 NAME

PocketIO::Base - Base class for transports

=head1 DESCRIPTION

L<PocketIO::Base> is a base class for the transports.

=head1 METHODS

=head2 C<new>

=head2 C<env>

=head2 C<req>

=head2 C<add_connection>

=head2 C<remove_connection>

=head2 C<find_connection>

=head2 C<client_connected>

=head2 C<client_disconnected>

=cut
