package PocketIO::Resource;

use strict;
use warnings;

use PocketIO::Transport::Htmlfile;
use PocketIO::Transport::JSONPPolling;
use PocketIO::Transport::WebSocket;
use PocketIO::Transport::XHRMultipart;
use PocketIO::Transport::XHRPolling;

use constant DEBUG => $ENV{POCKETIO_RESOURCE_DEBUG};

my %TRANSPORTS = (
    'xhr-multipart' => 'XHRMultipart',
    'xhr-polling'   => 'XHRPolling',
    'jsonp-polling' => 'JSONPPolling',
    'flashsocket'   => 'WebSocket',
    'websocket'     => 'WebSocket',
    'htmlfile'      => 'Htmlfile'
);

sub dispatch {
    my $self = shift;
    my ($env, $cb) = @_;

    my ($type) = $env->{PATH_INFO} =~ m{^/([^\/]+)/?};
    return unless $type;

    my $transport = $self->_build_transport($type, env => $env);
    return unless $transport;

    return $transport->dispatch($cb);
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

=head2 C<dispatch>

=cut
