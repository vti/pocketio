package PocketIO::Test;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::HTTP;
use Test::TCP;
use Plack::Loader;

use parent qw(Exporter);
our @EXPORT = qw(test_pocketio http_get_session_id);

sub test_pocketio {
    my ($app, $client) = @_;

    test_tcp(
        client => $client,
        server => sub {
            my $port = shift;
            my $server =
              Plack::Loader->auto(port => $port, host => ('127.0.0.1'));
            $server->run($app);
        },
    );
}

sub http_get_session_id {
    my $url = shift;

    my $cv = AnyEvent->condvar;

    my $session_id;

    $cv->begin;
    http_get $url, sub {
        my ($body, $hdr) = @_;

        ($session_id) = $body =~ m/^(\d+):/;
        $cv->end;
    };
    $cv->wait;

    return $session_id;
}

1;
__END__

=head1 NAME

PocketIO::Test - Testing PocketIO

=head1 DESCRIPTION

L<PocketIO::Test> is a L<PocketIO> testing simplified.

=head1 FUNCTIONS

=head2 C<test_pocketio>

=head2 C<http_get_session_id>

=cut
