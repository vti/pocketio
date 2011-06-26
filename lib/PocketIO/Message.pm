package PocketIO::Message;

use strict;
use warnings;

use JSON ();

our %TYPES = (
    'disconnect'   => 0,
    'connect'      => 1,
    'heartbeat'    => 2,
    'message'      => 3,
    'json_message' => 4,
    'event'        => 5,
    'ack'          => 6,
    'error'        => 7,
    'noop'         => 8
);

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub parse {
    my $self = shift;
    my ($string) = @_;

    ($self->{type}, $self->{id}, $self->{endpoint}, $self->{data}) =
      split ':', $string, 4;

    my %swapped = reverse %TYPES;
    $self->{type} = $swapped{$self->{type}};

    for (qw(id endpoint data)) {
        $self->{$_} = '' unless defined $self->{$_};
    }

    return $self;
}

sub type     { $_[0]->{type} }
sub id       { $_[0]->{id} }
sub endpoint { $_[0]->{endpoint} }

sub data {
    my $self = shift;

    if ($self->{type} eq 'error') {
        return join '+', $self->{reason}, $self->{advice};
    }

    if ($self->{type} eq 'json_message' || $self->{type} eq 'event') {
        return JSON::encode_json($self->{data});
    }

    return $self->{data};
}

sub to_bytes {
    my $self = shift;

    my @message;

    my $type = $TYPES{$self->{type}};

    for ($self->data, $self->{endpoint}, $self->{id}, $type) {
        if (@message) {
            push @message, defined $_ ? $_ : '';
        }
        elsif (defined $_) {
            push @message, $_;
        }
    }

    return join ':', reverse @message;
}

1;
