use strict;
use warnings;

use Test::More tests => 15;

use_ok('PocketIO::Message');

my $m = PocketIO::Message->new(type => 'disconnect', endpoint => '/test');
is $m->to_bytes, '0::/test';

$m = PocketIO::Message->new(type => 'disconnect');
is $m->to_bytes, '0';

$m = PocketIO::Message->new(type => 'connect', endpoint => '/test?my=param');
is $m->to_bytes, '1::/test?my=param';

$m = PocketIO::Message->new(type => 'heartbeat');
is $m->to_bytes, '2';

$m = PocketIO::Message->new(type => 'message', id => 1, data => 'blabla');
is $m->to_bytes, '3:1::blabla';

$m =
  PocketIO::Message->new(type => 'json_message', id => 1, data => {a => 'b'});
is $m->to_bytes, '4:1::{"a":"b"}';

$m = PocketIO::Message->new(
    type => 'event',
    id   => 1,
    data => {name => 'foo', args => ['foo']}
);
is $m->to_bytes, '5:1::{"args":["foo"],"name":"foo"}';

$m = PocketIO::Message->new(type => 'ack', data => 4);
is $m->to_bytes, '6:::4';

# TODO complex ack

$m = PocketIO::Message->new(
    type     => 'error',
    reason   => 'foo',
    advice   => 'bar',
    endpoint => '/test'
);
is $m->to_bytes, '7::/test:foo+bar';

$m = PocketIO::Message->new(type => 'noop');
is $m->to_bytes, '8';

$m = PocketIO::Message->new->parse('0::/test');
is $m->type, 'disconnect';
is $m->id, '';
is $m->endpoint, '/test';
is $m->data, '';
