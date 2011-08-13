my $root;

BEGIN {
    use File::Basename ();
    use File::Spec     ();

    $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../../lib";
}

use PocketIO;

use JSON;
use Plack::App::File;
use Plack::Builder;
use Plack::Middleware::Static;

my $nicknames = {};

builder {
    mount '/socket.io/socket.io.js' =>
      Plack::App::File->new(file => "$root/public/socket.io.js");

    mount '/socket.io/static/flashsocket/WebSocketMain.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMain.swf");

    mount '/socket.io/static/flashsocket/WebSocketMainInsecure.swf' =>
      Plack::App::File->new(file => "$root/public/WebSocketMainInsecure.swf");

    mount '/socket.io' => PocketIO->new(
        handler => sub {
            my $self = shift;

            $self->on(
                'user message' => sub {
                    my $self = shift;
                    my ($message) = @_;

                    $self->get('nick' => sub {
                        my ($self, $err, $nick) = @_;

                        $self->broadcast->emit('user message', $nick, $message);
                    });
                }
            );

            $self->on(
                'nickname' => sub {
                    my $self = shift;
                    my ($nick, $cb) = @_;

                    if ($nicknames->{$nick}) {
                        $cb->(JSON::true);
                    }
                    else {
                        $cb->(JSON::false);

                        $self->set(nick => $nick);

                        $nicknames->{$nick} = $nick;

                        $self->broadcast->emit('announcement', $nick . ' connected');
                        $self->sockets->emit('nicknames', $nicknames);
                    }
                }
            );

            $self->on(
                'disconnect' => sub {
                    my $self = shift;

                    $self->get(
                        'nick' => sub {
                            my ($self, $err, $nick) = @_;

                            delete $nicknames->{$nick};

                            $self->broadcast->emit('announcement',
                                $nick . ' disconnected');
                            $self->broadcast->emit('nicknames', $nicknames);
                        }
                    );
                }
            );
        }
    );

    mount '/' => builder {
        enable "Static",
          path => qr/\.(?:js|css|jpe?g|gif|png|html?|swf|ico)$/,
          root => "$root/public";

        enable "SimpleLogger", level => 'debug';

        my $html = do {
            local $/;
            open my $fh, '<', "$root/public/chat.html"
              or die $!;
            <$fh>;
        };

        sub {
            [   200,
                [   'Content-Type'   => 'text/html',
                    'Content-Length' => length($html)
                ],
                [$html]
            ];
        };
    };
};
