package WWW::LacunaExpanse::API::Building::Timer;

use Moose;
use Carp;

# Attributes
has 'remaining'     => (is => 'ro', required => 1);
has 'start'         => (is => 'ro', required => 1);
has 'end'           => (is => 'ro', required => 1);

1;
