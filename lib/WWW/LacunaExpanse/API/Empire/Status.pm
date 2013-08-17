package WWW::LacunaExpanse::API::Empire::Status;

use Moose;
use Carp;
use WWW::LacunaExpanse::API::Bits::DateTime;
use WWW::LacunaExpanse::API::Body::Status;

# This defines your own Empire and all the attributes and methods that go with it
# mostly, this is obtained by a call to /empire get_status

with 'WWW::LacunaExpanse::API::Role::Attributes';
with 'WWW::LacunaExpanse::API::Role::Call';

# Attributes based on the hash returned by the call
my $attributes = {
    id                      => 'Int',
    rpc_count               => 'Int',
    is_isolationist         => 'Int',
    name                    => 'Str',
    status_message          => 'Str',
    home_planet_id          => 'Int',
    has_new_messages        => 'Int',
    latest_message_id       => 'Int',
    essentia                => 'Num',
    planets                 => \'ArrayRef[WWW::LacunaExpanse::API::Body::Status]',
    tech_level              => 'Int',
    self_destruct_active    => 'Int',
    self_destruct_date      => \'WWW::LacunaExpanse::API::Bits::DateTime',
    alignment               => 'Str',
};

# private: path to the URL to call
has '_path'  => (
    is          => 'ro',
    default     => '/empire',
    init_arg    => undef,
);

has '_attributes' => (
    is          => 'ro',
    default     => sub {$attributes},
    init_arg    => undef,
);

create_attributes(__PACKAGE__, $attributes);

# Update by doing a call to get the objects status
#
sub update {
    my ($self) = @_;
    my $result = $self->call('get_status',{
        body_id     => $self->id,
    });
    $self->update_from_raw($result->{result}{empire});
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
