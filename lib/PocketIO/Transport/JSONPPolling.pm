package PocketIO::Transport::JSONPPolling;

use strict;
use warnings;

use base 'PocketIO::Transport::BasePolling';

use PocketIO::Util;

sub _get_content {
    my $self = shift;

    my $content = $self->SUPER::_get_content;

    return PocketIO::Util::urlencoded_param($content, 'd');
}

sub _content_type {'text/javascript; charset=UTF-8'}

sub _format_message {
    my $self = shift;
    my ($message) = @_;

    $message =~ s/"/\\"/g;
    return qq{io.j[0]("$message");};
}

1;
__END__

=head1 NAME

PocketIO::Transport::JSONPPolling - JSONPPolling transport

=head1 DESCRIPTION

L<PocketIO::Transport::JSONPPolling> is a C<jsonp-polling> transport implementation.

=head1 METHODS

Inherits all methods from L<PocketIO::Transport::BasePolling>.

=cut
