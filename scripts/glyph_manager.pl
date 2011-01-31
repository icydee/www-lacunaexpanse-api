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
use Log::Log4perl;
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
    Log::Log4perl::init("$Bin/../glyph_manager.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');
    $log->info('Program start');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");
    my $glyph_config    = YAML::Any::LoadFile("$Bin/../glyph_manager.yml");

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
        debug_hits  => $my_account->{debug_hits},
    });

    my $dsn     = "dbi:SQLite:dbname=$Bin/".$my_account->{db_file};
    my $schema  = WWW::LacunaExpanse::Schema->connect($dsn);

    my $tasks = {
        0.0     => \&_send_excavators,
        0.1     => \&_build_probes,
        0.3     => \&_start_glyph_search,
        0.4     => \&_build_excavators,
        0.5     => \&_transport_glyphs,
        5.0     => \&_transport_excavators,
        5.1     => \&_send_probes,
    };

    # Calculate tasks
    my $now             = DateTime->now;
    my $current_day     = $now->dow - 1;            # 0 = Monday
    my $current_hour    = $current_day * 24 + $now->hour;
    my $base_hour       = $glyph_config->{base_hour};
    my $task_hour       = ($base_hour + $current_hour) % 7;

#$task_hour = 5;

    my @current_tasks   = grep { int($_) == $task_hour } sort keys %$tasks;

    if ( ! @current_tasks ) {
        $log->info('Nothing to do at this time');
        exit;
    }

    ############
    # Gather as much information up-from about the empire so as not to
    # repeat it in the various sections later
    ############

    my $colonies = $api->my_empire->colonies;

    my @colony_data;
    my $total_excavators = 0;
    my @all_ship_yards;
    my @all_space_ports;
    my @all_archaeology;

    COLONY:
    for my $colony (sort {$a->name cmp $b->name} @$colonies) {

        $log->info('Gathering data for Colony '.$colony->name);

        $log->info('Getting space port');
        my $space_port = $colony->space_port;
        if ( ! $space_port ) {
            $log->warn('Has no space port!');
            next COLONY;
        }
        $log->info('Getting ship yards');
        my $ship_yards = $colony->building_type('Shipyard');
        $log->info('Getting archaeology ministry');
        my $archaeology = $colony->archaeology;
        $log->info('Getting trade ministry');
        my $trade_ministry = $colony->trade_ministry;

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
            $log->debug('There are '.scalar @$colony_excavators.' excavators on '.$colony->name);
            $total_excavators += scalar @$colony_excavators;
        }
        else {
            $log->debug('There are no excavators on '.$colony->name);
        }

        my $colony_datum = {
            api             => $api,
            colony          => $colony,
            space_port      => $space_port,
            trade_ministry  => $trade_ministry,
            ship_yards      => $ship_yards,
            archaeology     => $archaeology,
            glyphs          => $colony_glyph_summary,
            ships           => $ships_by_type,
            excavators      => $colony_excavators,
        };

        push @colony_data, $colony_datum;
    }


    ##########
    # Do all the tasks due on this hour
    ##########


    for my $key (@current_tasks) {

        &{$tasks->{$key}}({
            api                 => $api,
            schema              => $schema,
            config              => $glyph_config,
            colonies            => $colonies,
            colony_data         => \@colony_data,
            total_excavators    => $total_excavators,
            all_ship_yards      => \@all_ship_yards,
            all_space_ports     => \@all_space_ports,
            all_archaeology     => \@all_archaeology,
        });
    }
    $log->info('Program end');
}


####################################################################################
### Send probes out to new stars                                                 ###
####################################################################################

sub _send_probes {
    my ($args) = @_;

    my $log                 = Log::Log4perl->get_logger('MAIN::_send_probes');
    $log->info('_send_probes');

    my $config              = $args->{config};
    my $launch_colony_name  = $config->{excavator_launch_colony};
    my ($colony)            = grep {$_->name eq $launch_colony_name} @{$args->{colonies}};

    $log->info('Launch colony is '.$launch_colony_name);
    my $space_port          = $colony->space_port;
    my $observatory         = $colony->observatory;
    my $schema              = $args->{schema};
    my $api                 = $args->{api};

    my @probes_docked       = $space_port->all_ships('probe', 'Docked');
    my @probes_travelling   = $space_port->all_ships('probe', 'Travelling');

    my $centre_star = $api->find({ star => $config->{centre_star_name} }) || die "Cannot find star (".$config->{centre_star_name},")";

    # Max number of probes we can send is the observatory max_probes minus observatory probed_stars
    # minus the number of travelling probes.
    #
    my $observatory_probes_free = $observatory->max_probes - $observatory->count_probed_stars - scalar @probes_travelling;

    $log->debug("There are $observatory_probes_free slots available");
    $log->debug("There are ".scalar(@probes_docked)." docked probes");

    my $max_probes_to_send = min(scalar(@probes_docked), $observatory_probes_free);
    PROBE:
    while ($max_probes_to_send) {

        my ($probeable_star, $probe) = _next_star_to_probe($schema, $args->{config}, $space_port, $observatory, $centre_star);
        if ( ! $probeable_star ) {
            $log->error('Something seriously wrong. Cannot find a star to probe');
            last PROBE;
        }

        my $arrival_time = $space_port->send_ship($probe->id, {star_id => $probeable_star->id});
        $log->info('Sending probe ID '.$probe->id.' to star '.$probeable_star->name.' to arrive at '.$arrival_time);

        # mark the star as 'pending' the arrival of the probe
        $probeable_star->status(1);
        $probeable_star->update;

        $max_probes_to_send--;
    }
}


# Send excavators to probed systems
#
sub _send_excavators {
    my ($args) = @_;

    my $log                 = Log::Log4perl->get_logger('MAIN::_send_excavators');
    $log->info('_send_excavators');

    # Colony to send excavators out from
    my $launch_colony_name  = $args->{config}{excavator_launch_colony};
    my ($colony)            = grep {$_->name eq $launch_colony_name} @{$args->{colonies}};
    my $observatory         = $colony->observatory;
    my $schema              = $args->{schema};
    my $api                 = $args->{api};

    $log->info("Sending excavators out from colony $launch_colony_name");

    $observatory->refresh;
    my $probed_star = $observatory->next_probed_star;

    if (! $probed_star) {
        $log->warn('There are no more probed stars');
        return;
    }

    my ($db_star, $db_body_rs, $db_body);

    _save_probe_data($schema, $api, $probed_star);
    $db_star    = $schema->resultset('Star')->find($probed_star->id);
    $db_body_rs = $db_star->bodies;
    $db_body    = $db_body_rs->first;

    my $space_port  = $colony->space_port;
    if ( ! $space_port ) {
        $log->error('There is no space port');
        return;
    }

    my @excavators;

    $space_port->refresh;

    @excavators = $space_port->all_ships('excavator','Docked'); #<<<1+>>>#

    if ( ! @excavators) {
        $log->warn('There are no excavators to send');
        return;
    }
    $log->info('Colony '.$colony->name.' has '.scalar(@excavators).' docked excavators');

    # Send to a body around the next closest star
EXCAVATOR:
    while (@excavators && $probed_star) {
#         "checking next closest body ".$probed_star->name."\n";
        if ( ! $db_body ) {
            # Mark the star as exhausted, the probe can be abandoned
            $log->info('Star '.$probed_star->name.' has no more unexcavated bodies');
            $db_star->status(5);
            $db_star->update;
            $observatory->abandon_probe($probed_star->id);
            $observatory->refresh;

            $probed_star = $observatory->next_probed_star;
            last EXCAVATOR unless $probed_star;

            _save_probe_data($schema, $api, $probed_star);
            $db_star    = $schema->resultset('Star')->find($probed_star->id);
            $db_body_rs = $db_star->bodies;
            $db_body    = $db_body_rs->first;

            next EXCAVATOR;
        }
        # If the body is occupied, ignore it
        while ($db_body->empire_id) {
            $log->warn('Body '.$db_body->name.' is occupied, ignore it');
            $db_body = $db_body_rs->next;
            next EXCAVATOR if not $db_body;
        }
        $log->debug('Body '.$db_body->name.' is not occupied. empire_id='.$db_body->empire_id);

        # Get all excavators that can be sent to this planet
        my @send_excavators = grep {$_->type eq 'excavator'} @{$space_port->get_available_ships_for({ body_id => $db_body->id })}; #<<<1>>>#

        if ( ! @send_excavators ) {
            if ( ! @excavators) {
                # No more excavators at this colony
                $log->info('No more excavators to send from '.$colony->name);
                return;
            }
            $log->warn('Cannot send excavators to '.$db_body->name);
            $db_body = $db_body_rs->next;
            next EXCAVATOR;
        }

        my $distance = int(sqrt(($db_body->x - $colony->x)**2 + ($db_body->y - $colony->y)**2));
        $log->info('Sending exacavator to '.$db_body->name.' a distance of '.$distance);
        my $first_excavator = $send_excavators[0];
        $space_port->send_ship($first_excavator->id, {body_id => $db_body->id}); #<<<1>>>#
        @excavators = grep {$_->id != $first_excavator->id} @excavators;
        $space_port->refresh; #<<<2>>>#
        $db_body = $db_body_rs->next;
    }
}


# start a glyph search
#
sub _start_glyph_search {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_start_glyph_search');
    $log->error('_start_glyph_search: not yet implemented');
}

    ##########
    # Transport glyphs to the colony where they will be stored
    ##########

#    _transport_glyphs({
#        colony_data             => \@colony_data,
#        glyph_store_colony      => $glyph_config->{glyph_store_colony},
#        glyph_transport_type    => $glyph_config->{glyph_transport_type},
#        glyph_transport_name    => $glyph_config->{glyph_transport_name},
#    });

# Transport glyphs to the storage colony
#
sub _transport_glyphs {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_transport_glyphs');
    $log->info('_transport_glyphs');

    my @colony_data             = @{$args->{colony_data}};
    my $config                  = $args->{config};

    my $glyph_store_colony      = $config->{glyph_store_colony};
    my $glyph_transport_type    = $config->{glyph_transport_type};
    my $glyph_transport_name    = $config->{glyph_transport_name};

    COLONY:
    for my $colony_datum (@colony_data) {

        # Transport glyphs to the glyph store colony
        $log->debug('Checking for glyphs on '.$colony_datum->{colony}->name);
        if ($colony_datum->{colony}->name ne $glyph_store_colony) {
            ### We need to know how many glyphs there are on this colony at this point
            ###

            my ($glyph_ship) =
                grep {$_->name eq $glyph_transport_name}
                @{$colony_datum->{ships}{$glyph_transport_type}};
            if ($glyph_ship) {
                $log->debug('Ship to transport glyphs is '.$glyph_ship->id);
            }
            else {
                $log->error('Cannot find a transport for glyphs');
            }
        }
    }
}

# Transport built excavators to the exploration colony
#
sub _transport_excavators {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_transport_excavators');
    $log->info('_transport_excavators');

    my @colony_data                 = @{$args->{colony_data}};
    my $config                      = $args->{config};

    my ($excavator_launch_colony)   = grep {$_->name eq $config->{excavator_launch_colony}} @{$args->{colonies}};
    my $excavator_transport_type    = $config->{excavator_transport_type};
    my $excavator_transport_name    = $config->{excavator_transport_name};

    COLONY:
    for my $colony_datum (@colony_data) {
        # Transport the excavators to the launch colony

        next COLONY if ($colony_datum->{colony}->name eq $excavator_launch_colony->name);

        $log->info('Checking for completed excavators on '.$colony_datum->{colony}->name);
        my $trade_ministry = $colony_datum->{trade_ministry};
        if ( ! $trade_ministry ) {
            $log->error('No trade ministry found');
            next COLONY;
        }

        my @docked_excavators = grep {$_->task eq 'Docked'} @{$colony_datum->{excavators}};

        $log->info('Colony has '.scalar(@docked_excavators).' excavators to transport');
        if (@docked_excavators) {
            my @transport_ships =
                grep {$_->name eq $excavator_transport_name}
                @{$colony_datum->{ships}{$excavator_transport_type}};

            TRANSPORT:
            for my $transport_ship (grep {$_->task eq 'Docked'} @transport_ships) {
                last TRANSPORT if ! @docked_excavators;

                $log->info('Ship to transport excavators is '.$transport_ship->id);
                # How many excavators can the transporter transport?
                my $capacity = int($transport_ship->hold_size / 50000);
                if ($capacity) {
                    my @items;
                    while ($capacity && scalar @docked_excavators) {
                        my $ship = pop @docked_excavators;

                        $log->info('Pushing '.$ship->name);
                        push @items, {type => 'ship', ship_id => $ship->id};

                        $capacity--;
                    }
                    $log->info('Pushing to colony '.$excavator_launch_colony->name.' with ship '.$transport_ship->name);
                    $trade_ministry->push_items($excavator_launch_colony, \@items, {ship_id => $transport_ship->id});
                }
                else {
                    $log->error('The ship '.$transport_ship->name.' does not have capacity ('.$transport_ship->hold_size.') to transport other ships');
                }
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
sub _build_probes {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_build_probes');
    $log->info('_build_probes');
    my $config              = $args->{config};
    my @colony_data         = @{$args->{colony_data}};
    my $launch_colony_name  = $config->{excavator_launch_colony};
    my ($colony)            = grep {$_->name eq $launch_colony_name} @{$args->{colonies}};

    # Get all ship-yards at this colony
    my @ship_yards          = @{$colony->building_type('Shipyard')};


    my ($colony_datum)      = grep{$_->{colony}->name eq $config->{excavator_launch_colony}} @colony_data;
    $log->info('Launching probes from '.$colony->name);

    my $colony_probes       = @{$colony_datum->{ships}{probe}};
    $log->info('There are currently '.$colony_probes.' probes building, docked or travelling');

    my $to_build            = $config->{probe_count} - $colony_probes;
    my $max_build_level     = $config->{probe_max_build_level};

    if ($to_build <= 0) {
        $log->info('We have enough probes, no need to build more just yet');
        return;
    }
    $log->info('We need to build a further '.$to_build.' probes');

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

                $log->info('Building '.$ships_building.' probes at shipyard '.$shipyard->colony->name.' '.$shipyard->x.'/'.$shipyard->y);

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
# Finds all shipyards able to produce excavators
# Orders the shipyards by build queue size (smallest first)
# Then iterates through the shipyards adding one more excavator to each
# in a way that ensures that all build queues are leveled out and are kept
# to less than or equal to the config 'shipyard_max_builds'.
#
# You only need to keep the queues full enough so that it is still working
# the next time this routine is called
#


sub _build_excavators {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_build_excavators');
    $log->info('_build_excavators');

    my $total_excavators    = $args->{total_excavators};
    my $config              = $args->{config};
    my @all_ship_yards      = @{$args->{all_ship_yards}};

    my $shipyard_max_builds = $config->{shipyard_max_builds};
    my $to_build            = $config->{excavator_count} - $total_excavators;

    $log->info('We need to produce a further '.$to_build.' excavators');

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
        $log->debug("Shipyard on colony ".$shipyard->colony->name." plot ".$shipyard->x."/".$shipyard->y." has ".$shipyard->number_of_ships_building." ships building");
        if ($shipyard->number_of_ships_building < $shipyard_max_builds) {
            push @shipyards_sorted, $shipyard;
        }
    }

    # Distribute the building among those shipyards that can build
    # since the shipyards are sorted by the number of ships building we will have patterns like
    # 0,0,0,1,2,2,5 for the number of ships building
    # we need to make several passes through the data so the ships are built in the lowest queues
    # taking into account those shipyards which can't build any more (due to lack of space or resources)
    # We don't bother taking into account of the build times of all the shipyards.
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
                $log->debug('Start building at the first shipyard again');
                $min_free++;
                next EXCAVATOR;
            }

            # then build a ship
            $log->debug("Building ship at shipyard ".$shipyard->colony->name." ".$shipyard->x."/".$shipyard->y." min_free = $min_free ships_building = $ships_building");
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
            $log->warn('No more shipyards available');
            last EXCAVATOR;
        }
        $log->info('Increment min_free');
        $min_free++;
    }
}

# Save probe data in database

sub _save_probe_data {
    my ($schema, $api, $probed_star) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_save_probe_data');
    $log->info('_save_probe_data');

    # See if we have previously probed this star
    my $db_star = $schema->resultset('Star')->find($probed_star->id);

    if ($db_star->scan_date) {
        $log->debug("Previously scanned star system [".$db_star->name."]. Don't scan again");
        if ($db_star->status == 1) {
            $db_star->status(3);
            $db_star->update;
        }
    }
    else {
        $log->info("Saving scanned data for star system [".$db_star->name."]");
        for my $body (@{$probed_star->bodies}) {
            my $db_body = $schema->resultset('Body')->find($body->id);
            if ( $db_body ) {
                # We already have the body data, just update the empire data
                $db_body->empire_id($body->empire ? $body->empire->id : undef);
                $db_body->update;
            }
            else {
                # We need to create it
                my $db_body = $schema->resultset('Body')->create({
                    id          => $body->id,
                    orbit       => $body->orbit,
                    name        => $body->name,
                    x           => $body->x,
                    y           => $body->y,
                    image       => $body->image,
                    size        => $body->size,
                    type        => $body->type,
                    star_id     => $probed_star->id,
                    empire_id   => $body->empire ? $body->empire->id : undef,
                    water       => $body->water,
                });
                # Check the ores for this body
                my $body_ore = $body->ore;
                for my $ore_name (WWW::LacunaExpanse::API::Ores->ore_names) {
                    # we only store ore data if the quantity is greater than 1
                    if ($body_ore->$ore_name > 1) {
                        my $db_ore = $schema->resultset('LinkBodyOre')->create({
                            ore_id      => WWW::LacunaExpanse::API::Ores->ore_index($ore_name),
                            body_id     => $db_body->id,
                            quantity    => $body_ore->$ore_name,
                        });
                    }
                }

            }
        }
        $db_star->scan_date(DateTime->now);
        $db_star->status(3);
        $db_star->empire_id($api->my_empire->id);
        $db_star->update;
    }
}

# Get a new candidate star to probe
#
# Avoid sending a probe to a star we have visited in the last 30 days
#
sub _next_star_to_probe {
    my ($schema, $config, $space_port, $observatory, $centre_star) = @_;

    my ($star, $probe);

    my $log = Log::Log4perl->get_logger('MAIN::_next_star_to_probe');
    $log->info('_next_star_to_probe');

    # Locate a star at a random distance

    my $max_distance = $config->{max_distance};
    my $min_distance = $config->{min_distance};
    if ($config->{ultra_chance} && int(rand($config->{ultra_chance})) == 0 ) {
        $max_distance = $config->{ultra_max};
        $min_distance = $config->{ultra_min};
    }

    my $distance = int(rand($max_distance - $min_distance)) + $min_distance;

    $log->debug("Probing at a distance of $distance");

    # For now, only send to stars not previously probed.
    # In time all local stars will be 'mined out' but we can worry about that later.
    #
    my $distance_rs = $schema->resultset('Distance')->search_rs({
        from_id                 => $centre_star->id,
        distance                => {'>', $distance},
    }
    ,{
        join        => {to_star => 'probe_visits'},
        order_by    => 'distance',
    });

DISTANCE:
    while (my $distance = $distance_rs->next) {
        $star = $distance->to_star;

        # For now, ignore any stars we have previously probed. Later on
        # we will have to check for a date > 30 days ago
        if ($star->probe_visits->count) {
            $log->info("Ignoring ".$star->name." we have visited it before");
            next DISTANCE;
        }

        $log->debug("Getting available ships for ".$star->name);
        my $available_ships     = $space_port->get_available_ships_for({ star_id => $star->id });
        my @available_probes    = grep {$_->type eq 'probe'} @$available_ships;

        $probe = $available_probes[0];
        last DISTANCE if $probe;
    }
    # Update the database, so we don't send one there again
    $schema->resultset('ProbeVisit')->create({
        star_id     => $star->id,
        on_date     => WWW::LacunaExpanse::API::DateTime->now,
    });

    $log->debug("Probe ".$probe->id." found");
    return ($star,$probe);
}

1;
