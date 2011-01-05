package WWW::LacunaExpanse::API::Species;

use Moose;
use Carp;

# Attributes
has 'deception_affinity'        => (is => 'ro');
has 'description'               => (is => 'ro');
has 'environmental_affinity'    => (is => 'ro');
has 'farming_affinity'          => (is => 'ro');
has 'growth_affinity'           => (is => 'ro');
has 'management_affinity'       => (is => 'ro');
has 'manufacturing_affinity'    => (is => 'ro');
has 'max_orbit'                 => (is => 'ro');
has 'min_orbit'                 => (is => 'ro');
has 'mining_affinity'           => (is => 'ro');
has 'name'                      => (is => 'ro');
has 'political_affinity'        => (is => 'ro');
has 'research_affinity'         => (is => 'ro');
has 'science_affinity'          => (is => 'ro');
has 'trade_affinity'            => (is => 'ro');

1;
