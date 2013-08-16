package WWW::LacunaExpanse::API::Map::StarMap;

use Moose;
use Carp;
use WWW::LacunaExpanse::API::Bits::DateTime;
use WWW::LacunaExpanse::API::Body::Status;

with 'WWW::LacunaExpanse::API::Role::Connection';
with 'WWW::LacunaExpanse::API::Role::Attributes';

# Attributes based on the hash returned by the call
my $attributes = {
    id                      => 'Int',
    name                    => 'Str',
    x                       => 'Int',
    y                       => 'Int',
    station                 => \'WWW::LacunaExpanse::API::Bits::Station',
    bodies                  => \'ArrayRef[WWW::LacunaExpanse::API::Body::Status]',
};

# private: path to the URL to call
has '_path'  => (
    is          => 'ro',
    default     => '/map',
    init_arg    => undef,
);

has '_attributes' => (
    is          => 'ro',
    default     => sub {$attributes},
    init_arg    => undef,
);

create_attributes(__PACKAGE__, $attributes);

no Moose;
__PACKAGE__->meta->make_immutable;
1;
