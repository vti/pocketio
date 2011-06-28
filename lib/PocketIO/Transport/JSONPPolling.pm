package PocketIO::Transport::JSONPPolling;

use strict;
use warnings;

use base 'PocketIO::Transport::BasePolling';

sub name {'jsonp-polling'}

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

PocketIO::JSONPPolling - JSONPPolling transport

=head1 DESCRIPTION

L<PocketIO::JSONPPolling> is a C<jsonp-polling> transport
implementation.

=head1 METHODS

=head2 C<name>

=head2 C<dispatch>

=cut
