package WWW::LacunaExpanse::API::Role::Call;

use Moose::Role;
use Data::Dumper;

use WWW::LacunaExpanse::API::Connection;

has 'connection'        => (is => 'ro', lazy_build => 1);

sub _build_connection {
    return WWW::LacunaExpanse::API::Connection->instance;
}

sub call {
    my ($self, $uri, $args) = @_;
    $args->{session_id} = $self->connection->session_id;

    return $self->connection->call($self->_path, $uri, [$args]);
}

1
