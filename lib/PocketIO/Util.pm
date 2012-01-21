package PocketIO::Util;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = (qw/urlencoded_param/);

sub urlencoded_param {
    my ($string, $needed_key) = @_;

    return unless defined $string;

    my @pairs = split /(?:&|;)/, $string;
    for my $pair (@pairs) {
        my ($key, $value) = split /=/, $pair;

        $key =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg if defined $key;
        if ($key eq $needed_key) {
            $value =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg if defined $value;
            return $value;
        }
    }

    return;
}

1;
