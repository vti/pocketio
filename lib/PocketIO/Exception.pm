package PocketIO::Exception;

use strict;
use warnings;

use overload '""' => sub { $_[0]->to_string }, fallback => 1;

require Carp;

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;

    $self->{code} ||= 500;

    return $self;
}

sub code    { $_[0]->{code} }
sub message { $_[0]->{message} }

sub throw {
    my $class = shift;
    my ($code, $message) = @_;

    $message = '' unless defined $message;

    Carp::croak($class->new(code => $code, message => $message));
}

*as_string = \&to_string;
sub to_string { $_[0]->message }

1;
