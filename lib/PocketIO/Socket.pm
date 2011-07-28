package PocketIO::Socket;

use strict;
use warnings;

# DEPRECATED
sub send_message          {&send}
sub send_broadcast        { shift->broadcast->send(@_) }
sub send_broadcast_to_all { shift->sockets->send(@_) }
sub emit_broadcast        { shift->broadcast->emit(@_) }
sub emit_broadcast_to_all { shift->sockets->emit(@_) }

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{data} ||= {};

    return $self;
}

sub set {
    my $self = shift;
    my ($key, $value, $cb) = @_;

    $self->{data}->{$key} = $value;
    $cb->($self) if $cb;

    return $self;
}

sub get {
    my $self = shift;
    my ($key, $cb) = @_;

    my $value = $self->{data}->{$key};

    $cb->($self, undef, $value);

    return $self;
}

sub on {
    my $self  = shift;
    my $event = shift;

    my $name = "on_$event";

    unless (@_) {
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

    $self->{$event}->($self, @_);

    return $self;
}

sub send {
    my $self = shift;

    $self->{conn}->send(@_);

    return $self;
}

sub broadcast {
    my $self = shift;

    return $self->{conn}->broadcast(@_);
}

sub sockets {
    my $self = shift;

    return $self->{conn}->sockets(@_);
}

sub close {
    my $self = shift;

    $self->{conn}->close;

    return $self;
}

1;
