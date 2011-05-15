package PocketIO::Response::Chunked;

use strict;
use warnings;

sub finalize {
    [   200,
        ['Content-Type' => 'text/plain', 'Transfer-Encoding' => 'chunked'],
        ["2\x0d\x0aok\x0d\x0a" . "0\x0d\x0a\x0d\x0a"]
    ];
}

1;
