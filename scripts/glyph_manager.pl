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

MAIN: {
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

    # Try to gather as much information about the empire that we need
    # up-front in order to not repeat this in the various sections later.
    #
    COLONY:
    for my $colony (sort {$a->name cmp $b->name} @$colonies) {

        print "COLONY ".$colony->name."\n";

        print "Getting space port\n";
        my $space_port = $colony->space_port;
        if ( ! $space_port ) {
            print "Has no space port!\n";
            next COLONY;
        }
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


    ##########
    # Ensure there are enough excavators in the empire
    ##########

    print "There are a total of $total_excavators excavators in the empire\n";

    if ($total_excavators < $glyph_config->{excavator_count}) {
        _build_more_excavators({
            to_build            => $glyph_config->{excavator_count} - $total_excavators,
            shipyard_max_builds => $glyph_config->{shipyard_max_builds},
            all_ship_yards      => \@all_ship_yards,
        });
    } else {
        print "We have enough excavators in the empire no need to build more just yet!\n";
    }

    ##########
    # Ensure there are enough probes on the excavation colony
    ##########

    my ($colony_datum) = grep{$_->{colony}->name eq $glyph_config->{excavator_launch_colony}} @colony_data;
    print "The excavator launch colony is '".$colony_datum->{colony}->name."'\n";
    my $probes = @{$colony_datum->{ships}{probe}};
    print "There are '$probes' probes present on the exploration world '".$colony_datum->{colony}->name."'\n";

    if ($probes < $glyph_config->{probe_count}) {
        my $to_build = $glyph_config->{probe_count} - $probes;
        print "We need to build a further $to_build probes\n";
        _build_more_probes({
            to_build                => $to_build,
            ship_yards              => $colony_datum->{ship_yards},
            probe_max_build_level   => $glyph_config->{probe_max_build_level},
        });
    }
    else {
        print "We have enough probes ready to explore, no need to build more just yet!\n";
    }

    ##########
    # Transport excavators to the colony where they will be launched
    ##########

    _transport_excavators({
        colony_data     => \@colony_data,
        excavator_launch_colony     => $glyph_config->{excavator_launch_colony},
        excavator_transport_type    => $glyph_config->{excavator_transport_type},
        excavator_transport_name    => $glyph_config->{excavator_transport_name},
    });

    ##########
    # Transport glyphs to the colony where they will be stored
    ##########

    _transport_glyphs({
        colony_data             => \@colony_data,
        glyph_store_colony      => $glyph_config->{glyph_store_colony},
        glyph_transport_type    => $glyph_config->{glyph_transport_type},
        glyph_transport_name    => $glyph_config->{glyph_transport_name},
    });
}


# Transport glyphs to the storage colony
#
sub _transport_glyphs {
    my ($args) = @_;

    my @colony_data             = @{$args->{colony_data}};
    my $glyph_store_colony      = $args->{glyph_store_colony};
    my $glyph_transport_type    = $args->{glyph_transport_type};
    my $glyph_transport_name    = $args->{glyph_transport_name};

    COLONY:
    for my $colony_datum (@colony_data) {
        # Transport the glyphs to the storage
        print "Checking for glyps on '".$colony_datum->{colony}->name."'\n";

        # Transport glyphs to the glyph store colony
        print "Checking for glyphs on '".$colony_datum->{colony}->name."'\n";
        if ($colony_datum->{colony}->name ne $glyph_store_colony) {

            ### We need to know how many glyphs there are on this colony at this point
            ###

            my ($glyph_ship) =
                grep {$_->name eq $glyph_transport_name}
                @{$colony_datum->{ships}{$glyph_transport_type}};
            if ($glyph_ship) {
                print "ship to transport glyphs     is '".$glyph_ship->id."'\n";
            }
            else {
                print "WARNING: Cannot find a transport for glyphs\n";
            }
        }
    }
}


# Transport built excavators to the exploration colony
#
sub _transport_excavators {
    my ($args) = @_;

    my @colony_data                 = @{$args->{colony_data}};
    my $excavator_launch_colony     = $args->{excavator_launch_colony};
    my $excavator_transport_type    = $args->{excavator_transport_type};
    my $excavator_transport_name    = $args->{excavator_transport_name};

    COLONY:
    for my $colony_datum (@colony_data) {
        # Transport the excavators to the launch colony

        next COLONY if ($colony_datum->{colony}->name eq $excavator_launch_colony);

        print "Checking for excavators on '".$colony_datum->{colony}->name."'\n";
        my @docked_excavators = grep {$_->task eq 'Docked'} @{$colony_datum->{excavators}};

        print "Has ".scalar(@docked_excavators)." excavators to transport\n";
        if (@docked_excavators) {
            my ($excavator_ship) =
                grep {$_->name eq $excavator_transport_name}
                @{$colony_datum->{ships}{$excavator_transport_type}};
            if ($excavator_ship) {
                print "ship to transport excavators is '".$excavator_ship->id."'\n";
                # How many excavators can the transporter transport?
                my $capacity = int($excavator_ship->hold_size / 50);
                if ($capacity) {
                    while ($capacity && @docked_excavators) {
                        my $ship = pop @docked_excavators;

                        $capacity--;
                    }
                }
                else {
                    print "WARNING: The ship ".$excavator_ship->name." does not have capacity to transport ships\n";
                }

            }
            else {
                print "WARNING: Cannot find a transport for excavators\n";
            }
        }
    }
}


# Build more Probes on the exploration colony
#
#
# This is to ensure that the observatory is kept fully occupied since
# the excavators will abandon probes once they have excavated all available
# bodies in a system.
#
sub _build_more_probes {
    my ($args) = @_;

    my $to_build            = $args->{to_build};
    my @ship_yards          = @{$args->{ship_yards}};
    my $max_build_level     = $args->{probe_max_build_level};

    my $cant_build_at;
    my $build_level = 1;
    BUILD:
    while ($to_build && $build_level < $max_build_level) {
        my $at_least_one_built;

        SHIPYARD:
        for my $shipyard (@ship_yards) {

            # Ignore shipyards previously flagged as not being able to build
            next SHIPYARD if $cant_build_at->{$shipyard->id};

            my $ships_building = $shipyard->number_of_ships_building;
            if ($ships_building < $build_level) {
                # Build a probe here

                print "Building probe at shipyard ".$shipyard->colony->name." ".$shipyard->x."/".$shipyard->y." ships_building = $ships_building \n";

                if ( ! $shipyard->build_ship('probe') ) {
                    # We can't build at this shipyard any more
                    $shipyard->refresh;
                    $cant_build_at->{$shipyard->id} = 1;
                    next SHIPYARD;
                }
                $shipyard->refresh;
                $to_build--;
                $at_least_one_built = 1;
                last BUILD if ! $to_build;
            }
        }
        if ( ! $at_least_one_built) {
            $build_level++;
        }
    }
}


# Build More Excavators in the empire
#
#   to_build                - number of excavators to build
#   shipyard_max_builds     - maximum number of ships to put in shipyard build stack
#   all_shipyards           - list ref to all shipyards
#
# Finds all shipyards able to produce excavators
# Orders the shipyards by build queue size (smallest first)
# Then iterates through the shipyards adding one more excavator to each
# in a way that ensures that all build queues are leveled out and are kept
# to less than or equal to the config 'shipyard_max_builds'.
#
# You only need to keep the queues full enough so that it is still working
# the next time this routine is called
#
sub _build_more_excavators {
    my ($args) = @_;

    my $to_build            = $args->{to_build};
    my $shipyard_max_builds = $args->{shipyard_max_builds};
    my @all_ship_yards      = @{$args->{all_ship_yards}};

    print "We need to produce a further $to_build excavators\n";

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
        if ($shipyard->number_of_ships_building < $shipyard_max_builds) {
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
    while ($to_build && $min_free < $shipyard_max_builds) {

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

            $to_build--;
            $at_least_one_built = 1;
            last EXCAVATOR if $to_build <= 0;
        }

        unless ( $at_least_one_built ) {
            print "No more shipyards available\n";
            last EXCAVATOR;
        }
        print "Increment min_free\n";
        $min_free++;
    }
}


1;
