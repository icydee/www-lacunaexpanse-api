package WWW::LacunaExpanse::API::VirtualShip;

use Moose;
use Carp;

# This is not a 'real' ship, it is a potential ship such as a ship
# that could be built at a shipyard.

# Attributes
has 'type'              => (is => 'rw');
has 'hold_size'         => (is => 'rw');
has 'speed'             => (is => 'rw');
has 'stealth'           => (is => 'rw');
has 'cost'              => (is => 'rw');
has 'type_human'        => (is => 'rw');
has 'can'               => (is => 'rw');
has 'reason_code'       => (is => 'rw');
has 'reason_text'       => (is => 'rw');
has 'date_completed'    => (is => 'rw');

1;
