package PocketIO::Transport::Base;

use strict;
use warnings;

use Scalar::Util qw(weaken);

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;

    weaken $self->{env};
    weaken $self->{conn};

    return $self;
}

sub env  { $_[0]->{env} }
sub conn { $_[0]->{conn} }

sub client_connected {
    my $self = shift;
    my ($conn) = @_;

    return if $conn->is_connected;

    $conn->connected;
}

sub client_disconnected {
    my $self = shift;
    my ($conn) = @_;

    $conn->disconnected;

    $self->{on_disconnect}->($self);

    return $self;
}

1;
__END__

=head1 NAME

PocketIO::Transport::Base - Base class for transports

=head1 DESCRIPTION

L<PocketIO::Transport::Base> is a base class for the transports.

=head1 METHODS

=head2 C<new>

=head2 C<env>

=head2 C<req>

=head2 C<conn>

=head2 C<client_connected>

=head2 C<client_disconnected>

=cut
