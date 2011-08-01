package PocketIO::Test;

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket;
use Test::TCP;
use Plack::Loader;

use parent qw(Exporter);
our @EXPORT = qw(test_pocketio http_get_session_id);

sub test_pocketio {
    my ($app, $client) = @_;

    test_tcp(
        client => $client,
        server => sub {
            my $port   = shift;
            my $server = Plack::Loader->load(
                'Fliggy',
                port => $port,
                host => ('127.0.0.1')
            );
            $server->run($app);
        },
    );
}

sub http_get_session_id {
    my $server = shift;
    my $port   = shift;

    my $cv = AnyEvent->condvar;

    my $session_id;

    $cv->begin;
    tcp_connect $server, $port, sub {
        my ($fh) = @_ or return $cv->send;

        syswrite $fh, <<"EOF";
GET /socket.io/1/ HTTP/1.1
Host: $server:$port

EOF

        my $read_watcher;
        $read_watcher = AnyEvent->io(
            fh   => $fh,
            poll => "r",
            cb   => sub {
                my $len = sysread $fh, my $chunk, 1024, 0;

                if (($session_id) = $chunk =~ m/\r?\n(\d+):/) {
                    $cv->end;
                }

                if ($len <= 0) {
                    undef $read_watcher;
                    $cv->end;
                }
            }
        );
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
