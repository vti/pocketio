package Plack::Middleware::SocketIO::Handle;

use strict;
use warnings;

use AnyEvent::Handle;

sub new {
    my $class = shift;
    my ($fh) = @_;

    my $self = {handle => AnyEvent::Handle->new(fh => $fh)};
    bless $self, $class;

    $fh->autoflush;

    $self->{handle}->no_delay(1);
    $self->{handle}->on_eof(sub {});
    $self->{handle}->on_error(sub {});

    return $self;
}

sub heartbeat_timeout {
    my $self = shift;
    my ($timeout) = @_;

    $self->{heartbeat_timeout} = $timeout;

    return $self;
}

sub on_heartbeat {
    my $self = shift;
    my ($cb) = @_;

    $self->{handle}->timeout($self->{heartbeat_timeout});
    $self->{handle}->on_timeout($cb);

    return $self;
}

sub write {
    my $self = shift;
    my ($chunk, $cb) = @_;

    $self->{handle}->push_write($chunk);

    if ($cb) {
        $self->{handle}->on_drain(
            sub {
                $self->{handle}->on_drain(undef);

                $cb->($self);
            }
        );
    }

    return $self;
}

sub on_read {
    my $self = shift;
    my ($cb) = @_;

    $self->{handle}->on_read(
        sub {
            $cb->($self, $_[0]->rbuf);
        }
    );

    return $self;
}

1;
