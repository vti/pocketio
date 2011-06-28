use strict;
use warnings;
use utf8;

use Encode ();

use Test::More tests => 24;

use_ok('PocketIO::Message');

my $m = PocketIO::Message->new(type => 'disconnect', endpoint => '/test');
is $m->to_bytes, '0::/test';

$m = PocketIO::Message->new(type => 'disconnect');
is $m->to_bytes, '0';

$m = PocketIO::Message->new(type => 'connect');
is $m->to_bytes, '1::';

$m = PocketIO::Message->new(type => 'connect', endpoint => '/test?my=param');
is $m->to_bytes, '1::/test?my=param';

$m = PocketIO::Message->new(type => 'heartbeat');
is $m->to_bytes, '2::';

$m = PocketIO::Message->new(type => 'message', id => 1, data => 'blabla');
is $m->to_bytes, '3:1::blabla';

$m = PocketIO::Message->new(type => 'message', id => 1, data => 'привет');
is $m->to_bytes, Encode::encode('UTF-8', '3:1::привет');

$m = PocketIO::Message->new(id => 1, data => 'blabla');
is $m->to_bytes, '3:1::blabla';

$m =
  PocketIO::Message->new(type => 'json_message', id => 1, data => {a => 'b'});
is $m->to_bytes, '4:1::{"a":"b"}';

$m = PocketIO::Message->new(id => 1, data => {a => 'b'});
is $m->to_bytes, '4:1::{"a":"b"}';

$m =
  PocketIO::Message->new(type => 'json_message', id => 1, data => {a => 'привет'});
is $m->to_bytes, Encode::encode('UTF-8', '4:1::{"a":"привет"}');

$m = PocketIO::Message->new(
    type => 'event',
    id   => 1,
    data => {name => 'foo', args => ['foo']}
);
is $m->to_bytes, '5:1::{"args":["foo"],"name":"foo"}';

$m = PocketIO::Message->new(type => 'ack', message_id => 4);
is $m->to_bytes, '6:::4';

$m = PocketIO::Message->new(type => 'ack', message_id => 4, args => ['A', 'B']);
is $m->to_bytes, '6:::4+["A","B"]';

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
is $m->type,     'disconnect';
is $m->id,       '';
is $m->endpoint, '/test';
is $m->data,     '';

$m = PocketIO::Message->new->parse('4:1::{"a":"b"}');
is_deeply $m->data, {a => 'b'};

$m =
  PocketIO::Message->new->parse(Encode::encode('UTF-8', '3:1::привет'));
is $m->data, 'привет';

$m = PocketIO::Message->new->parse(
    Encode::encode('UTF-8', '4:1::{"a":"привет"}'));
is_deeply $m->data, {a => 'привет'};
