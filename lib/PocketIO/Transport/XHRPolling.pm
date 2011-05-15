package PocketIO::Transport::XHRPolling;

use strict;
use warnings;

use base 'PocketIO::Transport::BasePolling';

sub name {'xhr-polling'}

sub dispatch {
    my $self = shift;
    my ($cb) = @_;

    my $req  = $self->req;
    my $name = $self->name;

    if ($req->method eq 'GET') {
        return $self->_dispatch_init($cb) if $req->path =~ m{^/$name//\d+$};

        return $self->_dispatch_stream($1)
          if $req->path =~ m{^/$name/(\d+)/\d+$};
    }

    return
      unless $req->method eq 'POST'
          && $req->path_info =~ m{^/$name/(\d+)/send$};

    return $self->_dispatch_send($req, $1);
}

1;
__END__

=head1 NAME

PocketIO::XHRPolling - XHRPolling transport

=head1 DESCRIPTION

L<PocketIO::XHRPolling> is a C<xhr-polling> transport
implementation.

=head1 METHODS

=head2 C<name>

=head2 C<dispatch>

=cut
