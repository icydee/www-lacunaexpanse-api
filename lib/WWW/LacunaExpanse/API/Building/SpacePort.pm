package WWW::LacunaExpanse::API::Building::SpacePort;

use Moose;
use Carp;

extends 'WWW::LacunaExpanse::API::Building::Generic';

sub test {
    my ($self) = @_;

    print "I am a space-port\n";
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
