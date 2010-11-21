package WWW::LacunaExpanse::API::Building::Generic;

use Moose;
use Carp;

# Attributes
has 'id'                => (is => 'ro', required => 1);

my @simple_strings  = qw(name x y url level image efficiency);
my @date_strings    = qw();
my @other_strings   = qw(pending_build work);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', required => 1);
}

1;
