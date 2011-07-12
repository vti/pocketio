package PocketIO::Connection;

use strict;
use warnings;

use AnyEvent;

use PocketIO::Pool;
use PocketIO::Message;

use constant DEBUG => $ENV{POCKETIO_CONNECTION_DEBUG};

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{connect_timeout}   ||= 15;
    $self->{reconnect_timeout} ||= 15;
    $self->{close_timeout}     ||= 15;

    $self->{max_messages_to_stage} ||= 32;
    $self->{messages} = [];

    $self->{on_connect_failed}   ||= sub { };
    $self->{on_connect}          ||= sub { };
    $self->{on_reconnect}        ||= sub { };
    $self->{on_reconnect_failed} ||= sub { };
    $self->{on_message}          ||= sub { };
    $self->{on_disconnect}       ||= sub { };
    $self->{on_error}            ||= sub { };
    $self->{on_close}            ||= sub { };

    DEBUG && warn "Connection created\n";

    $self->connecting;

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
            DEBUG && warn "Timeout 'connect_timeout'\n";

            $self->emit('connect_failed');
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

            $self->emit('reconnect_failed');
        }
    );
}

sub connected {
    my $self = shift;

    DEBUG && warn "State 'connected'\n";

    delete $self->{connect_timer};

    $self->{is_connected} = 1;

    $self->emit('connect');

    my $message = PocketIO::Message->new(type => 'connect')->to_bytes;
    $self->_write($message);

    $self->_init_close_timer;

    return $self;
}

sub reconnected {
    my $self = shift;

    DEBUG && warn "State 'reconnected'\n";

    delete $self->{reconnect_timer};

    $self->emit('reconnect');

    $self->_init_close_timer;

    return $self;
}

sub disconnected {
    my $self = shift;

    DEBUG && warn "State 'disconnected'\n";

    delete $self->{connect_timer};
    delete $self->{reconnect_timer};
    delete $self->{close_timer};

    $self->{data}     = '';
    $self->{messages} = [];

    $self->{is_connected} = 0;


    $self->{disconnect_timer} = AnyEvent->timer(
        after => 0,
        cb    => sub {
            $self->emit('disconnect');
        }
    );

    return $self;
}

sub close {
    my $self = shift;

    $self->emit('close');

    $self->disconnected;

    return $self;
}

sub id {
    my $self = shift;

    $self->{id} ||= $self->_generate_id;

    return $self->{id};
}

sub on {
    my $self  = shift;
    my $event = shift;

    my $name = "on_$event";

    unless (@_) {
        DEBUG && warn "Event 'on_$event'\n";

        return $self->{$name};
    }

    $self->{$name} = $_[0];

    return $self;
}

sub emit {
    my $self  = shift;
    my $event = shift;

    $event = "on_$event";

    return unless exists $self->{$event};

    DEBUG && warn "Emitting '$event'\n";

    $self->{$event}->($self, @_);

    return $self;
}

sub parse_message {
    my $self = shift;
    my ($message) = @_;

    DEBUG && warn "Received '" . substr($message, 0, 80) . "'\n";

    $message = PocketIO::Message->new->parse($message);
    return unless $message;

    DEBUG && warn "Stop 'close_timer'\n";
    delete $self->{close_timer};

    if ($message->is_message) {
        $self->emit('message', $message->data);
    }
    elsif ($message->type eq 'event') {
        my $name = $message->data->{name};
        my $args = $message->data->{args};

        my $id = $message->id;

        $self->emit($name, @$args, sub {
            my $message = PocketIO::Message->new(
                type       => 'ack',
                message_id => $id,
                args       => [@_]
            )->to_bytes;

            $self->_write($message);
        });
    }
    elsif ($message->type eq 'heartbeat') {
        # TODO
    }
    else {
        # TODO
    }

    $self->_init_close_timer;

    return $self;
}

sub send_heartbeat {
    my $self = shift;

    $self->{heartbeat}++;

    my $message = PocketIO::Message->new(type => 'heartbeat')->to_bytes;

    return $self->_write($message);
}

sub send_message {
    my $self = shift;
    my ($message) = @_;

    $message = $self->_build_message($message);

    $self->_write($message);

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

sub emit_broadcast {
    my $self  = shift;
    my $event = shift;

    foreach my $conn (PocketIO::Pool->connections) {
        next if $conn->id eq $self->id;
        next unless $conn->is_connected;

        my $event = $self->_build_event_message($event, @_);

        $conn->_write($event);
    }

    return $self;
}

sub emit_broadcast_to_all {
    my $self  = shift;
    my $event = shift;

    foreach my $conn (PocketIO::Pool->connections) {
        next unless $conn->is_connected;

        my $event = $self->_build_event_message($event, @_);

        $conn->_write($event);
    }

    return $self;
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

sub _init_close_timer {
    my $self = shift;

    DEBUG && warn "Start 'close_timer'\n";

    $self->{close_timer} = AnyEvent->timer(
        after => $self->{close_timeout},
        cb    => sub {
            DEBUG && warn "Timeout 'close_timeout'\n";

            $self->close;
        }
    );
}

sub _build_message {
    my $self = shift;
    my ($message) = @_;

    return PocketIO::Message->new(data => $message)->to_bytes;
}

sub _build_event_message {
    my $self = shift;
    my $event = shift;

    return PocketIO::Message->new(
        type => 'event',
        data => {name => $event, args => [@_]}
    )->to_bytes;
}

sub _write {
    my $self = shift;
    my ($bytes) = @_;

    if ($self->on('write')) {
        DEBUG && warn "Writing '" . substr($bytes, 0, 50) . "'\n";
        $self->emit('write', $bytes);
    }
    else {
        $self->stage_message($bytes);
    }
}

sub _generate_id {
    my $self = shift;

    my $string = '';

    for (1 .. 16) {
        $string .= int(rand(10));
    }

    return $string;
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
