package WWW::LacunaExpanse::API::MyEmpire;

use Moose;
use Carp;

# Attributes
has 'connection'    => (is => 'ro', lazy_build => 1);

sub _build_connection {
    my ($self) = @_;

    return WWW::LacunaExpanse::API::Connection->instance;
}

# the full URI including the path
sub path {
    my ($self) = @_;
    return $self->connection->uri.'/empire';
}


1;
