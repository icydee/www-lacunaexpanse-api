package WWW::LacunaExpanse::API::Empire::PublicProfile;

use Moose;
use Carp;
use WWW::LacunaExpanse::API::Bits::DateTime;
use WWW::LacunaExpanse::API::Body::Status;

with 'WWW::LacunaExpanse::API::Role::Attributes';
with 'WWW::LacunaExpanse::API::Role::Call';

# Attributes based on the hash returned by the call
my $attributes = {
    id                      => 'Int',
    name                    => 'Str',
    colony_count            => 'Int',
    status_message          => 'Str',
    description             => 'Str',
    city                    => 'Str',
    country                 => 'Str',
    skype                   => 'Str',
    player_name             => 'Str',
    last_login              => \'WWW::LacunaExpanse::API::Bits::DateTime',
    date_founded            => \'WWW::LacunaExpanse::API::Bits::DateTime',
    species                 => 'Str',
    known_colonies          => \'ArrayRef[WWW::LacunaExpanse::API::Body::Status]',
    medals                  => \'ArrayRef[WWW::LacunaExpanse::API::Bits::Medal]',
    #alliance
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

sub update {
    my ($self) = @_;

    my $result = $self->call('get_public_profile',{
        empire_id   => $self->id,
    });
    $self->update_from_raw($result->{result}{public_profile});
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
