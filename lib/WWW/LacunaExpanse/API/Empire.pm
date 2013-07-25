package WWW::LacunaExpanse::API::Empire;

use Moose;
use Carp;
use WWW::LacunaExpanse::API::Empire::Status;
use WWW::LacunaExpanse::API::Empire::PublicProfile;

# This defines your own Empire and all the attributes and methods that go with it
# mostly, this is obtained by a call to /empire get_status

extends 'WWW::LacunaExpanse::API';

with 'WWW::LacunaExpanse::API::Role::Connection';

has 'id'        => (
    is          => 'ro',
    isa         => 'Int',
    required    => 1,
);

has '_path'      => (
    is          => 'ro',
    default     => '/empire',

);
has 'status'    => (
    is          => 'rw',
    isa         => 'WWW::LacunaExpanse::API::Empire::Status',
    lazy        => 1,
    builder     => '_build_status',
);

sub _build_status {
    my ($self) = @_;
    my $result = $self->connection->call($self->_path, 'get_status',[{
        session_id  => $self->connection->session_id, 
    }]);
    my $body = $result->{result}{empire};
    return WWW::LacunaExpanse::API::Empire::Status->new_from_raw($body);
    
}

sub view_public_profile {
    my ($self, $empire_id) = @_;

    $empire_id = $empire_id || $self->id;

    my $result = $self->connection->call($self->_path, 'view_public_profile',[{
        session_id  => $self->connection->session_id,
        empire_id   => $empire_id,
    }]);
    my $profile = $result->{result}{profile};
    return WWW::LacunaExpanse::API::Empire::PublicProfile->new_from_raw($profile);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
