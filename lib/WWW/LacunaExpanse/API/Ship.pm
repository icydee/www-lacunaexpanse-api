package WWW::LacunaExpanse::API::Ship;

use Moose;
use Carp;

# Attributes
has 'type'              => (is => 'rw');
has 'hold_size'         => (is => 'rw');
has 'speed'             => (is => 'rw');
has 'stealth'           => (is => 'rw');
has 'cost'              => (is => 'rw');
has 'type_human'        => (is => 'rw');


1;
