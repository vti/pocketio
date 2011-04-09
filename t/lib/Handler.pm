package Handler;

use strict;
use warnings;

sub new {
    my $class = shift;

    return bless {}, $class;
}

sub run {
    my $self = shift;

    return sub {
    };
}

1;
