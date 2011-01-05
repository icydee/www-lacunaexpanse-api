package WWW::LacunaExpanse::API::BuildingFactory;

# Abstract Factory for making Building Objects based on their name
#
use MooseX::AbstractFactory;
use Carp;

# hash of Buildings that have a non-generic building type
#
my $specials = {
    SpacePort               => 1,
    Observatory             => 1,
    Shipyard                => 1,
    ArchaeologyMinistry     => 1,
    GeneticsLab             => 1,
};

implementation_class_via sub {
    my ($name) = @_;

    # Check for special building names, otherwise they are 'Generic';
    if (! $specials->{$name}) {
        $name = 'Generic';
    }

    return "WWW::LacunaExpanse::API::Building::$name";
};

1;
