package PocketIO::Transport::JSONPPolling;

use strict;
use warnings;

use base 'PocketIO::Transport::BasePolling';

sub _get_content { $_[0]->req->body_parameters->get('d') }

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
