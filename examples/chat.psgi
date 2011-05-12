BEGIN {
    use File::Basename ();
    use File::Spec     ();

    my $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../lib";
}

use PocketIO;

use Plack::Builder;
use Plack::App::File;
use Plack::Middleware::Static;

my $path_to_socket_io = "/path/to/Socket.IO-node";

builder {
    mount '/socket.io/socket.io.js' => Plack::App::File->new(
        file => "$path_to_socket_io/support/socket.io-client/socket.io.js");

    mount '/socket.io' => PocketIO->new(
        handler => sub {
            my $self = shift;

            $self->on_message(
                sub {
                    my $self = shift;
                    my ($message) = @_;

                    $self->send_broadcast({message => [$self->id, $message]});
                }
            );

            $self->on_disconnect(
                sub {
                    $self->send_broadcast(
                        {announcement => $self->id . ' disconnected'});
                }
            );

            $self->send_message({buffer => []});

            $self->send_broadcast({announcement => $self->id . ' connected'});
        }
    );

    mount '/' => builder {
        enable "Static",
          path => qr/\.(?:js|css|jpe?g|gif|png|html?|js|css|swf|ico)$/,
          root => "$path_to_socket_io/example";

        enable "SimpleLogger", level => 'debug';

        sub {
            [   200,
                ['Content-Type' => 'text/html'],
                ['Open <a href="/chat.html">chat</a>.']
            ];
        };
    };
};
