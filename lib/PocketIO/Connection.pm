package PocketIO::Connection;

use strict;
use warnings;

use AnyEvent;
use JSON ();
use Encode ();
use Try::Tiny;

use PocketIO::Pool;

use constant DEBUG => $ENV{POCKETIO_CONNECTION_DEBUG};

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{connect_timeout}   ||= 15;
    $self->{reconnect_timeout} ||= 15;

    $self->{max_messages_to_stage} ||= 32;
    $self->{messages} = [];

    $self->{on_connect_failed}   ||= sub { };
    $self->{on_connect}          ||= sub { };
    $self->{on_reconnect}        ||= sub { };
    $self->{on_reconnect_failed} ||= sub { };
    $self->{on_message}          ||= sub { };
    $self->{on_disconnect}       ||= sub { };
    $self->{on_error}            ||= sub { };

    $self->{data} = '';

    DEBUG && warn "Connection created\n";

    return $self;
}

sub type { shift->{type} }

sub is_connected { $_[0]->{is_connected} }

sub connecting {
    my $self = shift;

    DEBUG && warn "State 'connecting'\n";

    $self->{connect_timer} = AnyEvent->timer(
        after => $self->{connect_timeout},
        cb    => sub {
            DEBUG && warn "Timeout 'connect_timeout'";

            $self->on('connect_failed')->($self);
        }
    );
}

sub reconnecting {
    my $self = shift;

    DEBUG && warn "State 'reconnecting'\n";

    $self->{reconnect_timer} = AnyEvent->timer(
        after => $self->{reconnect_timeout},
        cb    => sub {
            DEBUG && warn "Timeout 'reconnect_timeout'\n";

            $self->on('reconnect_failed')->($self);
        }
    );
}

sub connected {
    my $self = shift;

    DEBUG && warn "State 'connected'\n";

    delete $self->{connect_timer};

    $self->{is_connected} = 1;

    $self->on('connect')->($self);

    return $self;
}

sub reconnected {
    my $self = shift;

    DEBUG && warn "State 'reconnected'\n";

    delete $self->{reconnect_timer};

    $self->on('reconnect')->($self);

    return $self;
}

sub disconnected {
    my $self = shift;

    DEBUG && warn "State 'disconnected'\n";

    delete $self->{connect_timer};
    delete $self->{reconnect_timer};

    $self->{data}     = '';
    $self->{messages} = [];

    $self->{is_connected} = 0;

    $self->{disconnect_timer} = AnyEvent->timer(
        after => 0,
        cb    => sub {
            $self->on('disconnect')->($self);
        }
    );

    return $self;
}

sub id {
    my $self = shift;

    $self->{id} ||= $self->_generate_id;

    return $self->{id};
}

sub on_message    { shift->on(message    => @_) }
sub on_disconnect { shift->on(disconnect => @_) }
sub on_error      { shift->on(error      => @_) }
sub on_write      { shift->on(write      => @_) }

sub on {
    my $self = shift;
    my $event = shift;

    my $name = "on_$event";

    unless (@_) {
        DEBUG && warn "Event 'on_$event'\n";

        return $self->{$name};
    }

    $self->{$name} = $_[0];

    return $self;
}

sub read {
    my $self = shift;
    my ($data) = @_;

    return $self unless defined $data;

    $self->{data} .= Encode::decode('UTF-8', $data);

    while (my $message = $self->_parse_data) {
        $self->on('message')->($self, $message);
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

    $message = $self->build_message($message);

    if ($self->on_write) {
        $self->on('write')->($self, $message);
    }
    else {
        $self->stage_message($message);
    }

    return $self;
}

sub stage_message {
    my $self = shift;
    my ($message) = @_;

    return if @{$self->{messages}} >= $self->{max_messages_to_stage};

    push @{$self->{messages}}, $message;

    return $self;
}

sub has_staged_messages {
    my $self = shift;

    return @{$self->{messages}} > 0;
}

sub staged_message {
    my $self = shift;

    return shift @{$self->{messages}};
}

sub send_broadcast {
    my $self = shift;
    my ($message) = @_;

    foreach my $conn (PocketIO::Pool->connections) {
        next if $conn->id eq $self->id;
        next unless $conn->is_connected;

        $conn->send_message($message);
    }

    return $self;
}

sub send_id_message {
    my $self = shift;

    my $message = $self->build_id_message;

    $self->on('write')->($self, $message);

    return $self;
}

sub build_id_message {
    my $self = shift;

    return $self->build_message($self->id);
}

sub build_message {
    my $self = shift;
    my ($message) = @_;

    if (ref $message) {
        $message = '~j~' . JSON::encode_json($message);
    }
    else {
        $message = Encode::encode('UTF-8', $message);
    }

    return '~m~' . length(Encode::decode('UTF-8', $message)) . '~m~' . $message;
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
                    $json = JSON::decode_json(Encode::encode('UTF-8', $1));
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
