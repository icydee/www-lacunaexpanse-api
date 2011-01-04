package WWW::LacunaExpanse::API::Ship;

use Moose;
use Carp;

# Attributes
has 'id'                => (is => 'rw', required => 1);
has 'type'              => (is => 'rw');
has 'name'              => (is => 'rw');
has 'hold_size'         => (is => 'rw');
has 'speed'             => (is => 'rw');
has 'stealth'           => (is => 'rw');
has 'type_human'        => (is => 'rw');
has 'task'              => (is => 'rw');
has 'date_available'    => (is => 'rw');
has 'date_started'      => (is => 'rw');
has 'date_arrives'      => (is => 'rw');
has 'combat'            => (is => 'rw');
has 'max_occupants'     => (is => 'rw');
has 'estimated_travel_time' => (is => 'rw');

1;
