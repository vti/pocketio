package PocketIO::Connection;

use strict;
use warnings;

use JSON ();
use Try::Tiny;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{on_connect}    ||= sub { };
    $self->{on_message}    ||= sub { };
    $self->{on_disconnect} ||= sub { };
    $self->{on_error}      ||= sub { };

    $self->{data} = '';
    $self->{on_write}   ||= sub { };

    $self->{last_activity} = 0;

    return $self;
}

sub is_connected {
    my $self = shift;

    return $self->{is_connected};
}

sub connect {
    my $self = shift;

    $self->{is_connected} = 1;

    $self->{on_connect}->($self);

    $self->{last_activity} = time;

    return $self;
}

sub disconnect {
    my $self = shift;

    $self->{is_connected} = 0;

    $self->{on_disconnect}->($self);

    return $self;
}

sub id {
    my $self = shift;

    $self->{id} ||= $self->_generate_id;

    return $self->{id};
}

sub type {
    my $self = shift;
    my ($type) = @_;

    return $self->{type} unless defined $type;

    $self->{type} = $type;

    return $self;
}

sub on_message    { shift->on(message    => @_) }
sub on_disconnect { shift->on(disconnect => @_) }
sub on_error      { shift->on(error      => @_) }
sub on_write      { shift->on(write      => @_) }

sub on {
    my $self = shift;
    my ($event, $cb) = @_;

    my $name = "on_$event";

    return $self->{$name} unless $cb;

    $self->{$name} = $cb;

    return $self;
}

sub read {
    my $self = shift;
    my ($data) = @_;

    return $self unless defined $data;

    $self->{last_activity} = time;

    $self->{data} .= $data;

    while (my $message = $self->_parse_data) {
        $self->on_message->($self, $message);
    }

    return $self;
}

sub send_heartbeat {
    my $self = shift;

    $self->{heartbeat}++;

    return $self->send_message('~h~' . $self->{heartbeat});
}

sub send_message {
    my $self = shift;
    my ($message) = @_;

    $self->{last_activity} = time;

    $message = $self->_build_message($message);

    $self->on_write->($self, $message);

    return $self;
}

sub send_broadcast {
    my $self = shift;
    my ($message) = @_;

    my @conn = grep { $_->is_connected && $_->id ne $self->id }
      PocketIO::Resource->instance->connections;

    foreach my $conn (@conn) {
        $conn->send_message($message);
    }

    return $self;
}

sub send_id_message {
    my $self = shift;

    $self->{last_activity} = time;

    my $message = $self->build_id_message;

    $self->on_write->($self, $message);

    return $self;
}

sub build_id_message {
    my $self = shift;

    return $self->_build_message($self->id);
}

sub _build_message {
    my $self = shift;
    my ($message) = @_;

    if (ref $message) {
        $message = '~j~' . JSON::encode_json($message);
    }

    return '~m~' . length($message) . '~m~' . $message;
}

sub _generate_id {
    my $self = shift;

    my $string = '';

    for (1 .. 16) {
        $string .= int(rand(10));
    }

    return $string;
}

sub _parse_data {
    my $self = shift;

    if ($self->{data} =~ s/^~m~(\d+)~m~//) {
        my $length = $1;

        my $message = substr($self->{data}, 0, $length, '');
        if (length($message) == $length) {
            if ($message =~ m/^~h~(\d+)/) {
                my $heartbeat = $1;

                return $self->_parse_data;
            }
            elsif ($message =~ m/^~j~(.*)/) {
                my $json;

                try {
                    $json = JSON::decode_json($1);
                };

                return $json if defined $json;

                return $self->_parse_data;
            }
            else {
                return $message;
            }
        }
    }

    $self->{data} = '';
    return;
}

1;
__END__

=head1 NAME

PocketIO::Connection - Connection class

=head1 DESCRIPTION

L<PocketIO::Connection> is a connection class that
incapsulates all the logic for bulding and parsing Socket.IO messages.

=head1 METHODS

=head2 C<new>

=head2 C<id>

=head2 C<type>

=head2 C<disconnect>

=head2 C<is_connected>

=head2 C<on>

=head2 C<on_disconnect>

=head2 C<on_error>

=head2 C<on_message>

=head2 C<send_message>

=head2 C<send_broadcast>

=head1 INTERNAL METHODS

=head2 C<connect>

=head2 C<on_write>

=head2 C<read>

=head2 C<send_id_message>

=head2 C<build_id_message>

=head2 C<send_heartbeat>

=cut
