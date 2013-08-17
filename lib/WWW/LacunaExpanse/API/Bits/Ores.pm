package WWW::LacunaExpanse::API::Bits::Ores;

use Moose;
use Carp;

with 'WWW::LacunaExpanse::API::Role::Attributes';

my $attributes = {
    rutile          => 'Str',
    chromite        => 'Str',
    chalcopyrite    => 'Str',
    galena          => 'Str',
    gold            => 'Str',
    uraninite       => 'Str',
    bauxite         => 'Str',
    goethite        => 'Str',
    halite          => 'Str',
    gypsum          => 'Str',
    trona           => 'Str',
    kerogen         => 'Str',
    methane         => 'Str',
    anthracite      => 'Str',
    sulfur          => 'Str',
    zircon          => 'Str',
    monazite        => 'Str',
    fluorite        => 'Str',
    beryl           => 'Str',
    magnetite       => 'Str',
};

has '_attributes' => (
    is          => 'ro',
    default     => sub {$attributes},
    init_arg    => undef,
);

create_attributes(__PACKAGE__, $attributes);

no Moose;
__PACKAGE__->meta->make_immutable;
1;
