package PocketIO::Resource;

use strict;
use warnings;

use Plack::Request;

use PocketIO::Transport::Htmlfile;
use PocketIO::Transport::JSONPPolling;
use PocketIO::Transport::WebSocket;
use PocketIO::Transport::XHRMultipart;
use PocketIO::Transport::XHRPolling;

use constant DEBUG => $ENV{POCKETIO_RESOURCE_DEBUG};

my %TRANSPORTS = (
    'flashsocket'   => 'WebSocket',
    'htmlfile'      => 'Htmlfile',
    'jsonp-polling' => 'JSONPPolling',
    'websocket'     => 'WebSocket',
#    'xhr-multipart' => 'XHRMultipart',
    'xhr-polling'   => 'XHRPolling',
);

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{heartbeat_timeout} ||= 15;
    $self->{close_timeout}     ||= 25;
    $self->{max_connections}   ||= 100;

    $self->{transports} ||= [qw/websocket flashsocket htmlfile xhr-polling jsonp-polling/];

    return $self;
}

sub dispatch {
    my $self = shift;
    my ($env, $cb) = @_;

    my $method = $env->{REQUEST_METHOD};

    return unless $method eq 'POST' || $method eq 'GET';

    my $path_info = $env->{PATH_INFO};
    $path_info =~ s{^/}{};
    $path_info =~ s{/$}{};

    my ($protocol_version, $transport_id, $session_id) = split '/',
      $path_info, 3;
    return unless $protocol_version && $protocol_version =~ m/^\d+$/;

    if (!$transport_id && !$session_id) {
        return $self->_dispatch_handshake($env, $cb);
    }

    return unless $transport_id && $session_id;

    my $conn = $self->_find_connection($session_id);
    return unless $conn;

    my $transport = $self->_build_transport(
        $transport_id,
        env               => $env,
        pool              => $self->{pool},
        conn              => $conn,
        heartbeat_timeout => $self->{heartbeat_timeout},
        close_timeout     => $self->{close_timeout}
    );
    return unless $transport;

    return $transport->dispatch;
}

sub _dispatch_handshake {
    my $self = shift;
    my ($env, $cb) = @_;

    my $max_connections = $self->{max_connections};
    my $cur_connections = $self->{pool}->size;

    if ($cur_connections + 1 > $max_connections) {
        my $body = 'Service unavailable';
        return [503, ['Content-Length' => length $body], [$body]];
    }

    my $conn = $self->_build_connection(on_connect => $cb);

    my $transports = join ',', @{$self->{transports}};

    my $handshake = join ':', $conn->id, $self->{heartbeat_timeout},
      $self->{close_timeout}, $transports;

    my $req = Plack::Request->new($env);
    my $res = $req->new_response(200);

    # XDomain request
    if (defined(my $jsonp = $req->param('jsonp'))) {
        $res->content_type('application/javascript');
        $handshake = qq{io.j[$jsonp]("$handshake");};
    }
    else {
        $res->content_type('text/plain');
    }

    $res->headers->header('Connection' => 'keep-alive');
    $res->headers->header('Content-Length' => length($handshake));

    $res->body($handshake);

    return $res->finalize;
}

sub _build_connection {
    my $self = shift;

    return $self->{pool}->add_connection(@_);
}

sub _find_connection {
    my $self = shift;

    return $self->{pool}->find_connection(@_);
}

sub _build_transport {
    my $self = shift;
    my ($type, @args) = @_;

    return unless exists $TRANSPORTS{$type};

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
