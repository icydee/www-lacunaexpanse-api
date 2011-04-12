package WWW::LacunaExpanse::API::Plan;

use Moose;
use Carp;

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'name'              => (is => 'rw');
has 'level'             => (is => 'rw');
has 'extra_build_level' => (is => 'rw');

1;
