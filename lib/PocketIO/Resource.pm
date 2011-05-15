package PocketIO::Resource;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use Plack::Request;
use PocketIO::Connection;
use PocketIO::Handle;

use PocketIO::JSONPPolling;
use PocketIO::WebSocket;
use PocketIO::XHRMultipart;
use PocketIO::XHRPolling;
use PocketIO::Htmlfile;

sub instance {
    my $class = shift;

    no strict;

    ${"$class\::_instance"} ||= $class->_new_instance(@_);

    return ${"$class\::_instance"};
}

sub find_connection {
    my $self = shift;
    my ($conn) = @_;

    my $id = blessed $conn ? $conn->id : $conn;

    return $self->{connections}->{$id};
}

sub connections {
    my $self = shift;

    return values %{$self->{connections}};
}

sub add_connection {
    my $self = shift;

    my $conn = $self->_build_connection(@_);

    $self->{connections}->{$conn->id} = $conn;

    $conn->connecting;

    return $conn;
}

sub remove_connection {
    my $self = shift;
    my ($id) = @_;

    delete $self->{connections}->{$id};
}

sub finalize {
    my $self = shift;
    my ($env, $cb) = @_;

    my ($type) = $env->{PATH_INFO} =~ m{^/([^\/]+)/?};
    return unless $type;

    my $transport = $self->_build_transport($type, env => $env);
    return unless $transport;

    return $transport->finalize($cb);
}

sub _new_instance {
    my $class = shift;

    my $self = bless {@_}, $class;

    $self->{connections} = {};

    return $self;
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

    $class = "PocketIO::$class";

    return $class->new(@args);
}

sub _build_connection {
    my $self = shift;

    return PocketIO::Connection->new(@_,
        on_connection_failed => sub { $self->remove_connection($_[0]->id) });
}

1;
__END__

=head1 NAME

PocketIO::Resource - Resource class

=head1 DESCRIPTION

L<PocketIO::Resource> is a singleton connection pool.

=head1 METHODS

=head2 C<instance>

=head2 C<find_connection>

=head2 C<add_connection>

=head2 C<remove_connection>

=head2 C<finalize>

=cut
