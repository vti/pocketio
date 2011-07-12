package PocketIO::Message;

use strict;
use warnings;

use JSON ();
use Encode ();

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

    $self->{type} ||= ref $self->{data} ? 'json_message' : 'message';

    if ($self->{type} eq 'connect' || $self->{type} eq 'heartbeat') {
        $self->{endpoint} = '' unless defined $self->{endpoint};
    }

    return $self;
}

sub is_message {
    my $self = shift;

    return $self->type eq 'message' || $self->type eq 'json_message';
}

sub parse {
    my $self = shift;
    my ($string) = @_;

    return unless defined $string && $string ne '';

    ($self->{type}, $self->{id}, $self->{endpoint}, $self->{data}) =
      split ':', $string, 4;

    if ($self->{id} =~ s/\+$//) {
        # TODO ack
    }

    my %swapped = reverse %TYPES;
    $self->{type} = $swapped{$self->{type}};

    for (qw(id endpoint data)) {
        $self->{$_} = '' unless defined $self->{$_};
    }

    if ($self->{type} eq 'json_message' || $self->{type} eq 'event') {
        $self->{data} = JSON::decode_json($self->{data});
    }
    else {
        $self->{data} = Encode::decode('UTF-8', $self->{data});
    }

    return $self;
}

sub type     { $_[0]->{type} }
sub id       { $_[0]->{id} }
sub endpoint { $_[0]->{endpoint} }

sub data { $_[0]->{data} }

sub to_bytes {
    my $self = shift;

    my @message;

    my $type = $TYPES{$self->{type}};

    my $data;
    if ($self->{type} eq 'error') {
        $data = join '+', $self->{reason}, $self->{advice};
    }
    elsif ($self->{type} eq 'json_message' || $self->{type} eq 'event') {
        $data = JSON::encode_json($self->{data});
    }
    elsif ($self->{type} eq 'ack') {
        $data = $self->{message_id};
        if ($self->{args}) {
            $data .= '+' . JSON::encode_json($self->{args});
        }
    }
    else {
        $data = Encode::encode('UTF-8', $self->{data});
    }

    for ($data, $self->{endpoint}, $self->{id}, $type) {
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
