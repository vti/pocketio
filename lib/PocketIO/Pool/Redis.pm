package PocketIO::Pool::Redis;

use strict;
use warnings;

use base 'PocketIO::Pool';

use AnyEvent::Redis;
use JSON;
use Scalar::Util qw(blessed);

use PocketIO::Connection;

use constant DEBUG => $ENV{POCKETIO_POOL_DEBUG};

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{channel} ||= 'pocketio';

    $self->{redis} ||= {};

    $self->{pub} = $self->_create_client(%{$self->{redis}});
    $self->{sub} = $self->_create_client(%{$self->{redis}});

    $self->{sub}->subscribe(
        $self->{channel} => sub {
            my ($message, $channel) = @_;

            $message = decode_json($message);

            my $invoker_id = $message->{invoker};

            foreach my $conn ($self->_connections) {
                next unless $conn->is_connected;
                next if defined $invoker_id && $conn->id eq $invoker_id;

                $conn->write($message->{message});
            }
        }
    );

    return $self;
}

sub add_connection {
    my $self = shift;
    my $cb   = pop @_;

    my $conn = $self->_build_connection(@_);

    $self->{connections}->{$conn->id} = $conn;

    DEBUG && warn "Added connection '" . $conn->id . "'\n";

    $cb->($conn);
}

sub remove_connection {
    my $self = shift;
    my ($conn, $cb) = @_;

    my $id = blessed $conn ? $conn->id : $conn;

    delete $self->{connections}->{$id};

    DEBUG && warn "Removed connection '" . $id . "'\n";

    $cb->() if $cb;
}

sub send {
    my $self = shift;

    my $message = encode_json({message => "$_[0]"});

    $self->{pub}->publish($self->{channel}, $message);

    return $self;
}

sub broadcast {
    my $self    = shift;
    my $invoker = shift;

    my $message = encode_json({message => "$_[0]", invoker => $invoker->id});

    $self->{pub}->publish($self->{channel}, $message);

    return $self;
}

sub _create_client {
    my $self = shift;

    return AnyEvent::Redis->new(
        host     => '127.0.0.1',
        port     => 6379,
        encoding => 'utf8',
        on_error => sub {
            warn @_;
        },
        @_
    );
}

1;
__END__

=head1 NAME

PocketIO::Pool::Redis - Redis class

=head1 SYNOPSIS

    my $pocketio = PocketIO->new(pool => PocketIO::Pool::Redis->new);

=head1 DESCRIPTION

Uses Redis' pub/sub infrastructure 

=head1 METHODS

=head2 C<new>

Create new instance.

=head2 C<add_connection>

Add new connection.

=head2 C<remove_connection>

Remove connection.

=head2 C<broadcast>

Send broadcast message.

=head2 C<send>

Send message to all client.

=cut
