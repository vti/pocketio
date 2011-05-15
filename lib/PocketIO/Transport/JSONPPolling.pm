package PocketIO::Transport::JSONPPolling;

use strict;
use warnings;

use base 'PocketIO::Transport::BasePolling';

sub name {'jsonp-polling'}

sub dispatch {
    my $self = shift;
    my ($cb) = @_;

    my $req  = $self->req;
    my $name = $self->name;

    if ($req->method eq 'GET') {
        return $self->_dispatch_init($cb)
          if $req->path =~ m{^/$name//\d+/\d+$};

        return $self->_dispatch_stream($1)
          if $req->path =~ m{^/$name/(\d+)/\d+/\d+$};
    }

    return
      unless $req->method eq 'POST'
          && $req->path =~ m{^/$name/(\d+)/\d+/\d+$};

    return $self->_dispatch_send($req, $1);
}

sub _format_message {
    my $self = shift;
    my ($message) = @_;

    $message =~ s/"/\\"/g;
    return qq{io.JSONP[0]._("$message");};
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
