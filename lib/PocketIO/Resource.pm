package PocketIO::Resource;

use strict;
use warnings;

use Protocol::SocketIO::Handshake;
use Protocol::SocketIO::Path;

use PocketIO::Exception;
use PocketIO::Transport::Htmlfile;
use PocketIO::Transport::JSONPPolling;
use PocketIO::Transport::WebSocket;
use PocketIO::Transport::XHRMultipart;
use PocketIO::Transport::XHRPolling;
use PocketIO::Util;

use constant DEBUG => $ENV{POCKETIO_RESOURCE_DEBUG};

my %TRANSPORTS = (
    'flashsocket'   => 'WebSocket',
    'htmlfile'      => 'Htmlfile',
    'jsonp-polling' => 'JSONPPolling',
    'websocket'     => 'WebSocket',

#    'xhr-multipart' => 'XHRMultipart',
    'xhr-polling' => 'XHRPolling',
);

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{heartbeat_timeout} ||= 15;
    $self->{close_timeout}     ||= 25;
    $self->{max_connections}   ||= 100;

    $self->{transports}
      ||= [qw/websocket flashsocket htmlfile xhr-polling jsonp-polling/];

    return $self;
}

sub dispatch {
    my $self = shift;
    my ($env, $cb) = @_;

    my $method = $env->{REQUEST_METHOD};

    PocketIO::Exception->throw(400 => 'Unexpected method')
      unless $method eq 'POST' || $method eq 'GET';

    my $path_info = $env->{PATH_INFO};

    my $path =
      Protocol::SocketIO::Path->new(transports => $self->{transports})
      ->parse($path_info);
    PocketIO::Exception->throw(400 => 'Cannot parse path') unless $path;

    if ($path->is_handshake) {
        return $self->_dispatch_handshake($env, $cb);
    }

    my $conn = $self->_find_connection($path->session_id);
    PocketIO::Exception->throw(400 => 'Unknown session id') unless $conn;

    my $transport = $self->_build_transport(
        $path->transport_type,
        env           => $env,
        conn          => $conn,
        handle        => $self->_build_handle($env),
        on_disconnect => sub { $self->{pool}->remove_connection($conn) }
    );

    $conn->type($path->transport_type);

    return eval { $transport->dispatch } or do {
        my $e = $@;
        warn $e if DEBUG;
        die $e;
    };
}

sub _build_handle {
    my $self = shift;
    my ($env) = @_;

    return PocketIO::Handle->new(
        heartbeat_timeout => $self->{heartbeat_timeout},
        fh                => $env->{'psgix.io'}
    );
}

sub _dispatch_handshake {
    my $self = shift;
    my ($env, $cb) = @_;

    return sub {
        my $respond = shift;

        eval {
            $self->_build_connection(
                on_connect => $cb,
                $self->_on_connection_created($env, $respond)
            );

            1;
        } or do {
            my $e = $@;

            warn "Handshake error: $e";

            PocketIO::Exception->throw(503 => 'Service unavailable');
        };
    };
}

sub _build_connection {
    my $self = shift;

    $self->{pool}->add_connection(@_);
}

sub _on_connection_created {
    my $self = shift;
    my ($env, $respond) = @_;

    return sub {
        my $conn = shift;

        my $handshake = Protocol::SocketIO::Handshake->new(
            session_id        => $conn->id,
            transports        => $self->{transports},
            heartbeat_timeout => $self->{heartbeat_timeout},
            close_timeout     => $self->{close_timeout}
        )->to_bytes;

        my $headers = [];

        my $jsonp =
          PocketIO::Util::urlencoded_param($env->{QUERY_STRING}, 'jsonp');

        # XDomain request
        if (defined $jsonp) {
            push @$headers, 'Content-Type' => 'application/javascript';
            $handshake = qq{io.j[$jsonp]("$handshake");};
        }
        else {
            push @$headers, 'Content-Type' => 'text/plain';
        }

        push @$headers, 'Connection'     => 'keep-alive';
        push @$headers, 'Content-Length' => length($handshake);

        $respond->([200, $headers, [$handshake]]);
    };
}

sub _find_connection {
    my $self = shift;

    return $self->{pool}->find_connection(@_);
}

sub _build_transport {
    my $self = shift;
    my ($type, @args) = @_;

    PocketIO::Exception->throw(400 => 'Transport building failed')
      unless exists $TRANSPORTS{$type};

    my $class = "PocketIO::Transport::$TRANSPORTS{$type}";

    DEBUG && warn "Building $class\n";

    return $class->new(@args);
}

1;
__END__

=head1 NAME

PocketIO::Resource - Resource class

=head1 DESCRIPTION

L<PocketIO::Resource> is a transport dispatcher.

=head1 METHODS

=head2 C<new>

=head2 C<dispatch>

=cut
