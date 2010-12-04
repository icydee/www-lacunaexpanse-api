package WWW::LacunaExpanse::API::Cost;

use Moose;
use Carp;

# Attributes
has 'energy'    => (is => 'rw');
has 'food'      => (is => 'rw');
has 'ore'       => (is => 'rw');
has 'seconds'   => (is => 'rw');
has 'waste'     => (is => 'rw');
has 'water'     => (is => 'rw');

1;
