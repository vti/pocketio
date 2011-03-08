package Plack::Middleware::SocketIO::Base;

use strict;
use warnings;

use Plack::Middleware::SocketIO::Resource;
use JSON   ();
use Encode ();
use Try::Tiny;

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;

    return $self;
}

sub resource {
    my $self = shift;
    my ($resource) = @_;

    return $self->{resource} unless defined $resource;

    $self->{resource} = $resource;

    return $self;
}

sub add_connection {
    my $self = shift;

    return Plack::Middleware::SocketIO::Resource->instance->add_connection(@_);
}

sub find_connection_by_id {
    my $self = shift;
    my ($id) = @_;

    return Plack::Middleware::SocketIO::Resource->instance->connection($id);
}

1;
