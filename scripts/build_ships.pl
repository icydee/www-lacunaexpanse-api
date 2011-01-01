#!/home/icydee/localperl/bin/perl

# Script to ensure that all colonies have the correct number of ships
# of each type, e.g. probes/excavators etc.
#
# Generally this is used to ensure a stock of disposable ships are always
# available for other scripts.
#

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::Agent::ShipBuilder;

#### Configuration ####
my $username                = 'icydee';
my $password                = 'secret';

my $uri                     = 'https://us1.lacunaexpanse.com';
my $dsn                     = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

my $ships_required            = {
    'icydee 4'  => {
        probe       => {quantity => 8, priority => 4},
    },
    'icydee 5'  => {
        excavator   => {quantity => 18, priority => 3},
    },
    'icydee 6'  => {
        excavator   => {quantity => 16, priority => 3},
    },
    'icydee 7'  => {
        excavator   => {quantity => 14, priority => 3},
    },
    'icydee 8'  => {
        excavator   => {quantity => 16, priority => 3},
    },
};

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

my @colonies = grep {$ships_required->{$_->name}} @{$api->my_empire->colonies};

my @ship_builders;
COLONY:
for my $colony (@colonies) {
    print "Test ".$colony->name."\n";

    print "Building ships for colony [".$colony->name."]\n";

    my $space_port = $colony->space_port;
    my @shipyards = grep {$_->name eq 'Shipyard'} @{$colony->buildings};
    for my $shipyard (@shipyards) {
        my $ship_builder = WWW::LacunaExpanse::Agent::ShipBuilder->new({
            colony      => $colony,
            shipyard    => $shipyard,
            space_port  => $space_port,
            required    => $ships_required->{$colony->name},
        });
        push @ship_builders, $ship_builder;
    }
}

my $colony_delay;
map {$colony_delay->{$_->name} = 0} @colonies;

my $min_delay = 0;

while (1) {
    # Ensure that we scan at least twice an hour
    if ($min_delay > 30 * 60) {
        $min_delay = 30 * 60;
    }
#    print "Sleeping for $min_delay seconds\n";
    sleep($min_delay < 0 ? 1 : $min_delay);

    print "Refreshing space_port and shipyard data\n";
    for my $colony (@colonies) {
        $colony->space_port->refresh;
        $colony->shipyard->refresh;
    }
    # Adjust the delays
    for my $colony_name (keys %$colony_delay) {
        $colony_delay->{$colony_name} = $colony_delay->{$colony_name} - $min_delay;
    }

    # All colonies that have expired their timer
    my @colonies_to_test = grep {$colony_delay->{$_->name} <= 0} @colonies;
    for my $colony (@colonies_to_test) {
        print "\nTesting colony ".$colony->name."\n";
        $colony->shipyard->refresh;
        $colony->space_port->refresh;

        $colony_delay->{$colony->name} = $min_delay;

        my @ship_builders_to_test = grep {$_->colony->id eq $colony->id} @ship_builders;

        for my $ship_builder (@ship_builders_to_test) {
            print "Testing ship_builder ".$ship_builder->shipyard->x."/".$ship_builder->shipyard->y."\n";
            my $delay = $ship_builder->update;

            # Delay for the colony, is the delay until the first shipyard is finished
            if ($delay < $colony_delay->{$ship_builder->colony->name}) {
                $colony_delay->{$ship_builder->colony->name} = $delay;
            }
        }
    }
    print "\n\n\n";

    for my $colony_name (keys %$colony_delay) {
        print "Delay for colony ".$colony_name." is ".$colony_delay->{$colony_name}." seconds\n";
    }

    $min_delay = min map {$colony_delay->{$_}} keys %$colony_delay;

    # Wait at least 3 hours
    $min_delay = max ($min_delay, 180 * 60);
    print "BUILDING SHIPS again in ".int($min_delay/60)." minutes\n";

}


1;
