package PocketIO::Resource;

use strict;
use warnings;

use PocketIO::Transport::JSONPPolling;
use PocketIO::Transport::WebSocket;
use PocketIO::Transport::XHRMultipart;
use PocketIO::Transport::XHRPolling;
use PocketIO::Transport::Htmlfile;

use constant DEBUG => $ENV{POCKETIO_RESOURCE_DEBUG};

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

    my $class;
    if ($type eq 'xhr-multipart') {
        $class = 'XHRMultipart';
    }
    elsif ($type eq 'xhr-polling') {
        $class = 'XHRPolling';
    }
    elsif ($type eq 'jsonp-polling') {
        $class = 'JSONPPolling';
    }
    elsif ($type =~ m/^(?:flash|web)socket$/) {
        $class = 'WebSocket';
    }
    elsif ($type =~ m/^htmlfile$/) {
        $class = 'Htmlfile';
    }

    return unless $class;

    $class = "PocketIO::Transport::$class";

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
