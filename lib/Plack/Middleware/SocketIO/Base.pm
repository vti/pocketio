package Plack::Middleware::SocketIO::Base;

use strict;
use warnings;

use JSON   ();
use Encode ();
use Try::Tiny;

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;

    $self->{on_error}   ||= sub { };
    $self->{on_message} ||= sub { };

    $self->{heartbeat} = 0;

    $self->{data} = '';

    return $self;
}

sub id {
    my $self = shift;
    my ($id) = @_;

    return $self->{id} unless defined $id;

    $self->{id} = $id;

    return $self;
}

sub handle { shift->{handle} }

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

sub read {
    my $self = shift;
    my ($data) = @_;

    $self->{data} .= $data;

    while (my $message = $self->_parse_data) {
        $self->on_message->($self, $message);
    }

    return $self;
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

sub send_heartbeat {
    my $self = shift;

    $self->{heartbeat}++;

    return $self->send_message('~h~' . $self->{heartbeat});
}

sub send_message {
    my $self = shift;
    my ($message) = @_;

    $message = $self->_build_message($message);

    $message = $self->_format_message($message);

    $self->handle->write($message);
}

sub _build_message {
    my $self = shift;
    my ($message) = @_;

    if (ref $message) {
        $message = '~j~' . JSON::encode_json($message);
    }

    return '~m~' . length($message) . '~m~' . $message;
}

1;
