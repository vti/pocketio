use strict;
use warnings;

use PocketIO::Pool;
use Test::More tests => 2;

my $pool = PocketIO::Pool->new;

ok($pool);

my $sockets = PocketIO::Sockets->new(pool => $pool);

{
    # monkey patch PocketIO::Pool;
    no warnings 'redefine';
    my $message;
    local *PocketIO::Pool::send_raw = sub {
        my $self = shift;
        my %message = @_;
        $message = $message{message};
        return $self;
    };

    my $room = $sockets->in('test');
    $room->send({ test => 1 });
    is_deeply($message, { test => 1 }, "Room::send doesn't stringify message");
}

