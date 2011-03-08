package Plack::Middleware::SocketIO::Connection;

use strict;
use warnings;

use JSON ();
use Try::Tiny;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{on_error}   ||= sub { };
    $self->{on_connect} ||= sub { };
    $self->{on_write}   ||= sub { };
    $self->{on_message} ||= sub { };

    $self->{data} = '';

    return $self;
}

sub is_connected {
    my $self = shift;

    return $self->{is_connected};
}

sub connected {
    my $self = shift;

    $self->{is_connected} = 1;

    $self->{on_connect}->($self);

    return $self;
}

sub id {
    my $self = shift;

    $self->{id} ||= $self->_generate_id;

    return $self->{id};
}

sub transport {
    my $self = shift;
    my ($transport) = @_;

    return $self->{transport} unless defined $transport;

    $self->{transport} = $transport;

    return $self;
}

sub handle {
    my $self = shift;
    my ($handle) = @_;

    return $self->{handle} unless defined $handle;

    $self->{handle} = $handle;

    return $self;
}

sub on_error {
    my $self = shift;
    my ($cb) = @_;

    return $self->{on_error} unless $cb;

    $self->{on_error} = $cb;

    return $self;
}

sub on_message {
    my $self = shift;
    my ($cb) = @_;

    return $self->{on_message} unless $cb;

    $self->{on_message} = $cb;

    return $self;
}

sub on_write {
    my $self = shift;
    my ($cb) = @_;

    return $self->{on_write} unless $cb;

    $self->{on_write} = $cb;

    return $self;
}

sub read {
    my $self = shift;
    my ($data) = @_;

    return $self unless defined $data;

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

    $message = $self->_build_message($message);

    $self->on_write->($self, $message);

    return $self;
}

sub send_id_message {
    my $self = shift;

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
