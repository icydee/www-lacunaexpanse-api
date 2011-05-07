package WWW::LacunaExpanse::API::EmpireStats;

use Moose;
use Carp;

has 'empire'                    => (is => 'ro', required => 1);
has 'alliance_stat'             => (is => 'ro', required => 1);
has 'colony_count'              => (is => 'rw');
has 'population'                => (is => 'rw');
has 'empire_size'               => (is => 'rw');
has 'building_count'            => (is => 'rw');
has 'average_building_level'    => (is => 'rw');
has 'offense_success_rate'      => (is => 'rw');
has 'defense_success_rate'      => (is => 'rw');
has 'dirtiest'                  => (is => 'rw');

1;
