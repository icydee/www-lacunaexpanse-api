package WWW::LacunaExpanse::API::Role::Connection;

use Moose::Role;
use Data::Dumper;

use WWW::LacunaExpanse::API::Connection;

has 'connection'        => (is => 'ro', lazy_build => 1);

sub _build_connection {
    return WWW::LacunaExpanse::API::Connection->instance;
}

1
