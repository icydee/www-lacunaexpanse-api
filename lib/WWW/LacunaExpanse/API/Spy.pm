package WWW::LacunaExpanse::API::Spy;

use Moose;
use Carp;

# Attributes
has 'id'                    => (is => 'ro');
has 'name'                  => (is => 'ro');
has 'is_available'          => (is => 'ro');
has 'level'                 => (is => 'ro');
has 'mayhem'                => (is => 'ro');
has 'politics'              => (is => 'ro');
has 'theft'                 => (is => 'ro');
has 'intel'                 => (is => 'ro');
has 'offense_rating'        => (is => 'ro');
has 'defense_rating'        => (is => 'ro');
has 'possible_assignments'  => (is => 'ro');
has 'seconds_remaining'     => (is => 'ro');
has 'started_assignment'    => (is => 'ro');
has 'available_on'          => (is => 'ro');
has 'assignment'            => (is => 'ro');
has 'assigned_to'           => (is => 'ro');

1;
