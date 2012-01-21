package PocketIO::Connection;

use strict;
use warnings;

use AnyEvent;
use Scalar::Util qw(blessed);

use PocketIO::Message;
use PocketIO::Socket;
use PocketIO::Sockets;
use PocketIO::Broadcast;

use constant DEBUG => $ENV{POCKETIO_CONNECTION_DEBUG};

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{connect_timeout}   ||= 30;
    $self->{reconnect_timeout} ||= 15;
    $self->{close_timeout}     ||= 15;

    $self->{on_connect_timeout}   = sub { $_[0]->emit('connect_failed') };
    $self->{on_reconnect_timeout} = sub { $_[0]->emit('reconnect_failed') };
    $self->{on_close_timeout}     = sub { $_[0]->close };

    $self->{max_messages_to_stage} ||= 32;
    $self->{messages} = [];

    $self->{on_connect_failed}   ||= sub { };
    $self->{on_reconnect}        ||= sub { };
    $self->{on_reconnect_failed} ||= sub { };
    $self->{on_message}          ||= sub { };
    $self->{on_disconnect}       ||= sub { };
    $self->{on_error}            ||= sub { };
    $self->{on_close}            ||= sub { };

    $self->{socket} ||= $self->_build_socket;
    my $on_connect = delete $self->{on_connect} || sub { };
    $self->{on_connect} = sub {
        my $self = shift;
        my @args = @_;

        eval {
            $on_connect->($self->{socket}, @args);
            1;
        }
        or do {
            warn "Connection error: $_";

            $self->close;
        };
    };

    DEBUG && $self->_debug('Connection created');

    $self->connecting;

    return $self;
}

sub socket { $_[0]->{socket} }

sub pool { $_[0]->{pool} }

sub type { @_ > 1 ? $_[0]->{type} = $_[1] : $_[0]->{type} }

sub is_connected { $_[0]->{is_connected} }

sub connecting {
    my $self = shift;

    DEBUG && $self->_debug("State 'connecting'");

    $self->_start_timer('connect');
}

sub reconnecting {
    my $self = shift;

    DEBUG && $self->_debug("State 'reconnecting'");

    $self->_stop_timer('close');

    $self->_start_timer('reconnect');
}

sub connected {
    my $self = shift;

    DEBUG && $self->_debug("State 'connected'");

    $self->_stop_timer('connect');

    $self->{is_connected} = 1;

    my $message = PocketIO::Message->new(type => 'connect');
    $self->write($message);

    $self->_start_timer('close');

    $self->emit('connect');

    return $self;
}

sub reconnected {
    my $self = shift;

    DEBUG && $self->_debug("State 'reconnected'");

    $self->_stop_timer('reconnect');

    $self->emit('reconnect');

    $self->_start_timer('close');

    return $self;
}

sub disconnected {
    my $self = shift;

    DEBUG && $self->_debug("State 'disconnected'");

    $self->_stop_timer('connect');
    $self->_stop_timer('reconnect');
    $self->_stop_timer('close');

    $self->{data}     = '';
    $self->{messages} = [];

    $self->{is_connected} = 0;

    $self->{disconnect_timer} = AnyEvent->timer(
        after => 0,
        cb    => sub {
            return unless $self;

            if ($self->{socket}) {
                if (my $cb = $self->{socket}->on('disconnect')) {
                    $cb->($self->{socket});
                }
                undef $self->{socket};
            }

            undef $self;
        }
    );

    return $self;
}

sub close {
    my $self = shift;

    my $message = PocketIO::Message->new(type => 'disconnect');
    $self->write($message);

    $self->emit('close');

    #$self->disconnected;

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
        DEBUG && $self->_debug("Event 'on_$event'");

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

    DEBUG && $self->_debug("Emitting '$event'");

    $self->{$event}->($self, @_);

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

sub send_heartbeat {
    my $self = shift;

    $self->{heartbeat}++;

    DEBUG && $self->_debug('Send heartbeat');

    my $message = PocketIO::Message->new(type => 'heartbeat');

    return $self->write($message);
}

sub send {
    my $self = shift;
    my ($message) = @_;

    $message = $self->_build_message($message);

    $self->write($message);

    return $self;
}

sub broadcast {
    my $self = shift;

    return PocketIO::Broadcast->new(conn => $self, pool => $self->pool);
}

sub sockets {
    my $self = shift;

    return PocketIO::Sockets->new(pool => $self->pool);
}

sub parse_message {
    my $self = shift;
    my ($message) = @_;

    DEBUG && $self->_debug("Received '" . substr($message, 0, 80) . "'");

    $message = PocketIO::Message->new->parse($message);
    return unless $message;

    $self->_stop_timer('close');

    if ($message->is_message) {
        $self->{socket}->on('message')->($self->{socket}, $message->data);
    }
    elsif ($message->type eq 'event') {
        my $name = $message->data->{name};
        my $args = $message->data->{args};

        my $id = $message->id;

        $self->{socket}->on($name)->(
            $self->{socket},
            @$args => sub {
                my $message = PocketIO::Message->new(
                    type       => 'ack',
                    message_id => $id,
                    args       => [@_]
                );

                $self->write($message);
            }
        );
    }
    elsif ($message->type eq 'heartbeat') {

        # TODO
    }
    else {

        # TODO
    }

    $self->_start_timer('close');

    return $self;
}

sub write {
    my $self = shift;
    my ($bytes) = @_;

    $self->_restart_timer('close');

    $bytes = $bytes->to_bytes if blessed $bytes;

    if ($self->on('write')) {
        DEBUG && $self->_debug("Writing '" . substr($bytes, 0, 50) . "'");
        $self->emit('write', $bytes);
    }
    else {
        DEBUG && $self->_debug("Staging '" . substr($bytes, 0, 50) . "'");
        $self->stage_message($bytes);
    }
}

sub _start_timer {
    my $self = shift;
    my ($timer) = @_;

    my $timeout = $self->{"${timer}_timeout"};

    DEBUG && $self->_debug("Start '${timer}_timer' ($timeout)");

    $self->{"${timer}_timer"} = AnyEvent->timer(
        after => $timeout,
        cb    => sub {
            DEBUG && $self->_debug("Timeout '${timer}_timeout'");

            $self->{"on_${timer}_timeout"}->($self);
        }
    );
}

sub _stop_timer {
    my $self = shift;
    my ($timer) = @_;

    DEBUG && $self->_debug("Stop '${timer}_timer'");

    delete $self->{"${timer}_timer"};
}

sub _restart_timer {
    my $self = shift;
    my ($timer) = @_;

    $self->_stop_timer($timer);
    $self->_start_timer($timer);
}

sub _build_message {
    my $self = shift;
    my ($message) = @_;

    return $message if blessed $message;

    return PocketIO::Message->new(data => $message);
}

sub _generate_id {
    my $self = shift;

    my $string = '';

    for (1 .. 16) {
        $string .= int(rand(10));
    }

    return $string;
}

sub _debug {
    my $self = shift;
    my ($message) = @_;

    warn time . ' (' . $self->id . '): ' . $message . "\n";
}

sub _build_socket {
    my $self = shift;

    return PocketIO::Socket->new(conn => $self);
}

1;
__END__

=head1 NAME

PocketIO::Connection - Connection class

=head1 DESCRIPTION

L<PocketIO::Connection> is a connection class that
incapsulates all the logic for bulding and parsing Socket.IO messages. Used
internally.

=head1 METHODS

=head2 C<broadcast>

=head2 C<close>

=head2 C<connected>

=head2 C<connecting>

=head2 C<disconnected>

=head2 C<emit>

=head2 C<has_staged_messages>

=head2 C<id>

=head2 C<is_connected>

=head2 C<new>

=head2 C<on>

=head2 C<parse_message>

=head2 C<pool>

=head2 C<reconnected>

=head2 C<reconnecting>

=head2 C<send>

=head2 C<send_heartbeat>

=head2 C<socket>

=head2 C<sockets>

=head2 C<stage_message>

=head2 C<staged_message>

=head2 C<type>

=head2 C<write>

=cut
