package WWW::LacunaExpanse::API::Building::SpacePort;

use Moose;
use Carp;

extends 'WWW::LacunaExpanse::API::Building::Generic';

sub test {
    my ($self) = @_;

    print "I am a space-port\n";
}



1;
