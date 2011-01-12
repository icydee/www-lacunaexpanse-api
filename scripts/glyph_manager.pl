#!/home/icydee/localperl/bin/perl

# Manage Glyphs
#
# Gather information about all colonies.
#   All space-ports
#   All ship-yards
#   All archaeology-ministries
#   The number of glyphs on each colony
#   The number and type of each ship on each colony
#
# Ensure there are enough excavators in the Empire (set in the config)
# If we need to produce excavators set ship-yards into production
# keeping the number of ships in each ship-yard to a minimum (ideally 1)
#
# If there are docked excavators on any colony planets transport them to
# the gas giant where the massive space-ports are.
#
# Ensure there are enough probes on the Gas Giant, if not build them
#
# If there are docked probes, send them out to random stars
#
# If there are docked excavators on the GG send them out
#
# Trade push any glyphs on colonies to the home world
#
# Check the glyph trades on the trade ministry.
#   Send out an SMS for any especially low glyph costs
#
# Check the glyph trades on the Subspace Transporter
#   Remove individual glyph trades put up by others at a lower price
#   Add individual glyph trades that are not on the SST at a premium price
#   Add glyph packs subject to a minimum number of glyphs in stock.
#

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::Agent::ShipBuilder;

# Load configurations

my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");
my $glyph_config    = YAML::Any::LoadFile("$Bin/../glyph_manager.yml");

my $api = WWW::LacunaExpanse::API->new({
    uri         => $my_account->{uri},
    username    => $my_account->{username},
    password    => $my_account->{password},
    debug_hits  => $my_account->{debug_hits},
});

print "Getting colonies\n";
my $colonies = $api->my_empire->colonies;

my @colony_data;
my $total_excavators = 0;
my @all_ship_yards;
my @all_space_ports;
my @all_archaeology;

# Get the buildings for each colony.
for my $colony (sort {$a->name cmp $b->name} @$colonies) {

    print "COLONY ".$colony->name."\n";
    print "Getting space port\n";
    my $space_port = $colony->space_port;
    print "Getting ship yards\n";
    my $ship_yards = $colony->building_type('Shipyard');
    print "Getting archaeology ministry\n";
    my $archaeology = $colony->archaeology;

    push @all_ship_yards, @$ship_yards;
    push @all_space_ports, $space_port;
    push @all_archaeology, $archaeology;

    my $colony_glyph_summary = {};

    if ($archaeology) {
        # Get all the glyphs held on this colony
        $colony_glyph_summary = $archaeology->get_glyph_summary;
    }

    # Get all the ships held on this colony by type
    my $ships_by_type = $space_port->all_ships_by_type;

    my $colony_excavators;
    if ($ships_by_type->{excavator}) {
        $colony_excavators = $ships_by_type->{excavator};
        print "there are ".scalar @$colony_excavators." excavators on ".$colony->name."\n";
        $total_excavators += scalar @$colony_excavators;
    }
    else {
        print "there are no excavators on ".$colony->name."\n";
    }
    my $colony_datum = {
        colony      => $colony,
        space_port  => $space_port,
        ship_yards  => $ship_yards,
        archaeology => $archaeology,
        glyphs      => $colony_glyph_summary,
        ships       => $ships_by_type,
        excavators  => $colony_excavators,
    };

    push @colony_data, $colony_datum;
#    last if $colony->name eq 'icydee 3';
}

# Ensure there are enough excavators in the empire
print "There are a total of $total_excavators excavators in the empire\n";

if ($total_excavators < $glyph_config->{excavator_count}) {
    my $more_excavators = $glyph_config->{excavator_count} - $total_excavators;
    print "We need to produce a further $more_excavators excavators\n";

    # Find all shipyards able to build excavators
    my @shipyards_buildable;
    for my $shipyard (@all_ship_yards) {
        my ($can_build_excavator) = grep {$_->type eq 'excavator' && $_->can_build} @{$shipyard->buildable};
        if ($can_build_excavator) {
            if ($shipyard->docks_available) {
                push @shipyards_buildable, $shipyard;
            }
        }
    }

    # Order all shipyards by the build queue size (increasing) which are below the max build queue size
    my @shipyards_sorted;
    for my $shipyard (sort {$a->number_of_ships_building <=> $b->number_of_ships_building} @shipyards_buildable) {
        print "Shipyard on colony ".$shipyard->colony->name." plot ".$shipyard->x."/".$shipyard->y." has ".$shipyard->number_of_ships_building." ships building\n";
        if ($shipyard->number_of_ships_building < $glyph_config->{shipyard_max_builds}) {
            push @shipyards_sorted, $shipyard;
        }
    }

    # Distribute the building among those shipyards that can build
    # since the shipyards are sorted by the number of ships building we will have patterns like
    # 0,0,0,1,2,2,5 for the number of ships building
    # we need to make several passes through the data so the ships are built in the lowest queues
    # taking into account those shipyards which can't build any more (due to lack of space or resources)
    #
    my $min_free = 0;
    my $cant_build_at;                  # hash of shipyards we can't build at
    EXCAVATOR:
    while ($more_excavators && $min_free < $glyph_config->{shipyard_max_builds}) {

        my $at_least_one_built = 0;
        SHIPYARD:
        for my $shipyard (@shipyards_sorted) {

            # Ignore shipyards previously flagged as not being able to build
            next SHIPYARD if $cant_build_at->{$shipyard->id};

            my $ships_building = $shipyard->number_of_ships_building;
            if ($min_free < $ships_building) {
                # start again at the beginning of the shipyard list
                print "Start building at the first shipyard again\n";
                $min_free++;
                next EXCAVATOR;
            }

            # then build a ship
            print "Building ship at shipyard ".$shipyard->colony->name." ".$shipyard->x."/".$shipyard->y." min_free = $min_free ships_building = $ships_building \n";
            if ( ! $shipyard->build_ship('excavator') ) {
                # We can't build at this shipyard any more
                $shipyard->refresh;
                $cant_build_at->{$shipyard->id} = 1;
                next SHIPYARD;
            }
            $shipyard->refresh;

            # If the shipyard can't handle it, then put it on the $cant_build_at hash and ignore it

            $more_excavators--;
            $at_least_one_built = 1;
            last EXCAVATOR if $more_excavators <= 0;
        }

        unless ( $at_least_one_built ) {
            print "No more shipyards available\n";
            last EXCAVATOR;
        }
        print "Increment min_free\n";
        $min_free++;
    }

    # Order all space-ports by the number of spare docks they have (decreasing)
} else {
    print "We have enough excavators in the empire no need to build more just yet!\n";
}

### Transport excavators to the colony where they will be launched ###
COLONY:
for my $colony_datum (@colony_data) {
    # Transport the excavators to the launch colony
    print "Checking for excavators on '".$colony_datum->{colony}->name."'\n";
    if ($colony_datum->{colony}->name ne $glyph_config->{excavator_launch_colony}) {
        my @docked_excavators = grep {$_->task eq 'Docked'} @{$colony_datum->{excavators}};

        print "Has ".scalar(@docked_excavators)." excavators to transport\n";
        if (@docked_excavators) {
            my ($excavator_ship) =
                grep {$_->name eq $glyph_config->{excavator_transport_name}}
                @{$colony_datum->{ships}{$glyph_config->{excavator_transport_type}}};
            if ($excavator_ship) {
                print "ship to transport excavators is '".$excavator_ship->id."'\n";
            }
            else {
                print "WARNING: Cannot find a transport for excavators\n";
            }
        }
    }

    # Transport glyphs to the glyph store colony
    print "Checking for glyphs on '".$colony_datum->{colony}->name."'\n";
    if ($colony_datum->{colony}->name ne $glyph_config->{glyph_store_colony}) {

        ### We need to know how many glyphs there are on this colony at this point
        ###

        my ($glyph_ship) =
            grep {$_->name eq $glyph_config->{glyph_transport_name}}
            @{$colony_datum->{ships}{$glyph_config->{glyph_transport_type}}};
        if ($glyph_ship) {
            print "ship to transport glyphs     is '".$glyph_ship->id."'\n";
        }
        else {
            print "WARNING: Cannot find a transport for glyphs\n";
        }
    }
}


1;
