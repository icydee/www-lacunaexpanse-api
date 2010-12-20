#!/home/icydee/localperl/bin/perl

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
my $username                = 'username';
my $password                = 'password';

my $uri                     = 'https://us1.lacunaexpanse.com';
my $dsn                     = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

# Find all colonies which have level 15 or above archaeology ministries
# together with a shipyard and space port
my @colonies;
COLONY:
for my $colony (@{$api->my_empire->colonies}) {
#    next COLONY unless $colony->name eq 'icydee-2-8';
    my @archaeologies = grep {$_->level >= 15} @{$colony->building_type('Archaeology Ministry')};

#    print "Colony ".$colony->name." has ".scalar(@archaeologies). " Archaeology Ministries\n";
    for my $building (@archaeologies) {
        # The colony must also have a space port and a shipyard
        if ( ! $colony->space_port) {
            print "Sorry - ".$colony->name." has no space port\n";
            next COLONY;
        }
        if (! $colony->shipyard) {
            print "Sorry - ".$colony->name." has no shipyard\n";
            next COLONY;
        }
        push @colonies, $colony;
    }
}

my @ship_builders;
for my $colony (@colonies) {
    print "We are sending excavators from colony [".$colony->name."]\n";

    my $space_port = $colony->space_port;
    my @shipyards = grep {$_->name eq 'Shipyard'} @{$colony->buildings};
    for my $shipyard (@shipyards) {
        my $ship_builder = WWW::LacunaExpanse::Agent::ShipBuilder->new({
            colony      => $colony,
            shipyard    => $shipyard,
            space_port  => $space_port,
            required    => {
                excavator   => {quantity => 6, priority => 3},
            },
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
    print "Sleeping for $min_delay seconds\n";
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
        my @ship_builders_to_test = grep {$_->colony->id eq $colony->id} @ship_builders;

        for my $ship_builder (@ship_builders_to_test) {

            my $delay = $ship_builder->update;

            if ($colony_delay->{$ship_builder->colony->name}) {
                # Delay for the colony, is the delay until the first shipyard is finished
                if ($delay < $colony_delay->{$ship_builder->colony->name}) {
                    $colony_delay->{$ship_builder->colony->name} = $delay;
                }
            }
            else {
                $colony_delay->{$ship_builder->colony->name} = $delay;
            }
        }
    }
    print "\n\n\n";

    for my $colony_name (keys %$colony_delay) {
        print "Delay for colony ".$colony_name." is ".$colony_delay->{$colony_name}." seconds\n";
    }

    $min_delay = min map {$colony_delay->{$_}} keys %$colony_delay;

    print "Minimum delay is $min_delay\n";

}


1;
