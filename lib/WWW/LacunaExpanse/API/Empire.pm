package WWW::LacunaExpanse::API::Empire;

use Moose;
use Carp;
use WWW::LacunaExpanse::API::Empire::Status;
use WWW::LacunaExpanse::API::Empire::PublicProfile;
use WWW::LacunaExpanse::API::Empire::OwnProfile;

# This defines your own Empire and all the attributes and methods that go with it
# mostly, this is obtained by a call to /empire get_status


with 'WWW::LacunaExpanse::API::Role::Call';

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
has 'own_profile' => (
    is          => 'rw',
    isa         => 'WWW::LacunaExpanse::API::Empire::OwnProfile',
    lazy        => 1,
    builder     => '_build_own_profile',
);


sub _build_status {
    my ($self) = @_;

    my $result = $self->call('get_status');
    my $body = $result->{result}{empire};
    return WWW::LacunaExpanse::API::Empire::Status->new_from_raw($body);
    
}

sub _build_own_profile {
    my ($self) = @_;
    my $result = $self->call('get_own_profile');
    my $body = $result->{result}{own_profile};
    return WWW::LacunaExpanse::API::Empire::OwnProfile->new_from_raw($body);

}

sub get_public_profile {
    my ($self, $empire_id) = @_;

    return WWW::LacunaExpanse::API::Empire::PublicProfile->new({
        id   => $empire_id,
    });
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
