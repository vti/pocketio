BEGIN {
    use File::Basename ();
    use File::Spec ();

    my $root = File::Basename::dirname(__FILE__);
    $root = File::Spec->rel2abs($root);

    unshift @INC, "$root/../lib";
}

use Plack::Builder;
use Plack::App::File;
use Plack::Middleware::Static;
use Plack::Middleware::SocketIO;

my $path_to_socket_io = "/path/to/Socket.IO-node";

builder {
    mount '/socket.io/socket.io.js' => Plack::App::File->new(
        file => "$path_to_socket_io/support/socket.io-client/socket.io.js");

    mount '/' => builder {
        enable "Static",
          path => qr/\.(?:js|css|jpe?g|gif|png|html?|js|css|swf|ico)$/,
          root => "$path_to_socket_io/example";

        enable "SimpleLogger",
          level => 'debug';

        enable "SocketIO", handler => sub {
            my $self = shift;

            $self->on_message(sub {
                    my $self = shift;
                    my ($message) = @_;

                    $self->send_message(
                        {   message => [
                                $self->id,
                                join '' => reverse split '' => $message
                            ]
                        }
                    );
                }
            );

            $self->send_message({buffer => []});
        };

        sub {
            [   200,
                ['Content-Type' => 'text/html'],
                ['Open <a href="/chat.html">chat</a>.']
            ];
        };
    };
};
