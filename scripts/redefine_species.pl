#!/home/icydee/localperl/bin/perl

# Script to redefine our species

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;

#### Configuration ####
my $username                = 'icydee';
my $password                = 'secret';

my $uri                     = 'https://us1.lacunaexpanse.com';
my $dsn                     = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

my $my_empire   = $api->my_empire;

$my_empire->redefine_species_limits;

$my_empire->redefine_species({
    name                    => 'icydee',
    min_orbit               => 1,
    max_orbit               => 3,
    manufacturing_affinity  => 3,
    deception_affinity      => 7,
    research_affinity       => 3,
    management_affinity     => 3,
    farming_affinity        => 3,
    mining_affinity         => 3,
    science_affinity        => 4,
    environmental_affinity  => 4,
    political_affinity      => 4,
    trade_affinity          => 7,
    growth_affinity         => 1,
});

1;
