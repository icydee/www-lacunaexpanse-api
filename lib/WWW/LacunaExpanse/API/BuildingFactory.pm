package WWW::LacunaExpanse::API::BuildingFactory;

# Abstract Factory for making Building Objects based on their name
#
use MooseX::AbstractFactory;
use Carp;

# hash of Buildings that have a none-generic building type
#
my $specials = {
    SpacePort       => 1,
    Observatory     => 1,
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
