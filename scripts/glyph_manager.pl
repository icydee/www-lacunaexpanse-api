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
# TODO:
#
# Put in a timeout on API calls
# MUST be able to exclude colonies (such as exp and spw) from building excavators
# Update time of probe_visit at the point the probe is destroyed to more closely match the excavation time
# Use the same method for 'build_probes' as we do for 'build_excavators' i.e. don't call  get_buildable and view_build_queue for each probe
# Use the probe_visit table to exclude star systems that have been visited in the past 35 days
# Create a probe_visit entry when the probe is abandoned, not when the probe is sent out
# After determining 'launch colony is xyz' why do we call view_all_ships twice? get it from colony_data
# Add routine to check email for excavator result messages, store in database and put messages into archive
# Add diagnostic to show the number of API hits taken during the running of the script and the number remaining for the day
# Implement a shut-down of the script if we don't have enough API calls left for the day.
# When building excavators, don't do prior calls to 'get_buildable' just build and catch the exception
# Add an auto-login for when the server resets or we lose our session, automatically re-do the last command
#
# DONE
#
# When there are no more excavators to build, don't call get_buildable for all shipyards!
# Implement start_glyph_search for glyphs that we have the least of at each archaeology ministry
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

    # Tasks to do on the hour (units) and the order to do them in (decimal)
    my $tasks = {
        0.0     => \&_send_excavators,
        0.1     => \&_build_probes,
        0.4     => \&_build_excavators,
        2.0     => \&_transport_excavators,
        2.1     => \&_send_probes,
        3.0     => \&_send_excavators,
        3.1     => \&_build_probes,
        3.3     => \&_start_glyph_search,
        3.4     => \&_build_excavators,
        3.5     => \&_transport_glyphs,
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
        $log->info("Nothing to do on task hour $task_hour");
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

#next COLONY if $colony->name eq 'hw3';

#next COLONY if $colony->name ne 'exp';
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
        push @all_space_ports, $space_port if $space_port;
        push @all_archaeology, $archaeology if $archaeology;

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
    $log->info("Program end at hour $task_hour");
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

        my $distance = int(sqrt(($db_body->x - $colony->x)**2 + ($db_body->y - $colony->y)**2));
        $log->info('Trying to send exacavator to '.$db_body->name.' a distance of '.$distance);

        # No longer do API calls to check which excavators can be sent, just send them
        # and catch the exception. It takes 1 call rather than 4 per excavator sent.
        my $first_excavator = $excavators[0];
        my $success = $space_port->send_ship($first_excavator->id, {body_id => $db_body->id}); #<<<1>>>#
        if ($success) {
            shift @excavators;
#            @excavators = grep {$_->id != $first_excavator->id} @excavators;
        }
        $db_body = $db_body_rs->next;
    }
}


# start a glyph search
# The current algorithm tries to maximise the number of Halls
# if you want it to do anything else please do so via the YAML configuration
#
sub _start_glyph_search {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_start_glyph_search');

    my $config          = $args->{config};
    my $algorithm       = $config->{glyph_search_algorithm};
    my @colony_data     = @{$args->{colony_data}};
    my @all_archaeology = @{$args->{all_archaeology}};

    # Get the total of all glyphs on all colonies
    my $combined_glyphs;
    for my $glyph_name (WWW::LacunaExpanse::API::Ores->ore_names) {
        $combined_glyphs->{$glyph_name} = 0;
    }
    for my $colony_datum (@colony_data) {
        my $colony_glyphs = $colony_datum->{glyphs};

        for my $glyph_name (keys %$colony_glyphs) {
            if ($colony_glyphs->{$glyph_name}) {
                $combined_glyphs->{$glyph_name} += $colony_glyphs->{$glyph_name};
            }
        }
    }
    # list of glyph names, in the order they are to be searched for
    my @glyph_sort_order;

    if ($algorithm eq 'maximise_halls') {
        my $hall_def = {
            a   => [qw(goethite halite gypsum trona)],
            b   => [qw(gold anthracite uraninite bauxite)],
            c   => [qw(kerogen methane sulfur zircon)],
            d   => [qw(monazite fluorite beryl magnetite)],
            e   => [qw(rutile chromite chalcopyrite galena)],
        };

        my $glyph_weight;

        for my $glyph (keys %$combined_glyphs) {
            $glyph_weight->{$glyph} = 0;
        }

        for my $hall (keys %$hall_def) {
            my @g_array = @{$hall_def->{$hall}};
            # get the min and max values
            my $max_glyphs = max(map {$combined_glyphs->{$_}} @g_array);
            for my $g (@g_array) {
                $glyph_weight->{$g} = $max_glyphs - $combined_glyphs->{$g};
            }
        }
        @glyph_sort_order = sort {$glyph_weight->{$b} <=> $glyph_weight->{$a}} keys %$combined_glyphs;
    }
    else {
        $log->error("Glyph search algorithm '$algorithm' is not implemented");
        return;
    }
    $log->info('GLYPH SORT ORDER '.join('-', @glyph_sort_order));

    # Now go through all archaeology ministries and start a search
ARCHAEOLOGY:
    for my $archaeology (@all_archaeology) {
        $log->info("Searching archaeology ministry ".$archaeology->x.":".$archaeology->y." on colony ".$archaeology->colony->name);
        my @ores_for_processing = @{$archaeology->get_ores_available_for_processing};
        $log->info("Ores for processing = ".join('-', map {$_->type} @ores_for_processing));
        my $done_search = 0;
        for my $ore_type (@glyph_sort_order) {
            my $do_search = grep {$ore_type eq $_->type} @ores_for_processing;

            if ($do_search) {
                $done_search = 1;
                if ($archaeology->search_for_glyph($ore_type)) {
                    $log->info("Searching for glyph type '$ore_type' at colony ".$archaeology->colony->name);
                }
                else {
                    $log->warn("Already searching for glyphs at colony ".$archaeology->colony->name);
                }
                next ARCHAEOLOGY;
            }
        }
        if (! $done_search) {
            $log->warn('No ores to search at archaeology on colony '.$archaeology->colony->name);
        }
    }
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

    my ($glyph_store_colony)    = grep {$_->name eq $config->{glyph_store_colony}} @{$args->{colonies}};
#print Dumper($glyph_store_colony);
    my $glyph_transport_type    = $config->{glyph_transport_type};
    my $glyph_transport_name    = $config->{glyph_transport_name};

    COLONY:
    for my $colony_datum (@colony_data) {

        # Transport glyphs to the glyph store colony
        $log->debug('colony name '.$colony_datum->{colony}->name.' glyph store colony '.$glyph_store_colony->name);

        if ($colony_datum->{colony}->name ne $glyph_store_colony->name) {
            $log->debug('Checking for glyphs on '.$colony_datum->{colony}->name);
            my $trade_ministry = $colony_datum->{trade_ministry};
            next COLONY if not $trade_ministry;

            my @glyphs = @{$trade_ministry->get_glyphs};

            if (@glyphs) {
                my ($glyph_ship) =
                    grep {$_->name eq $glyph_transport_name}
                    @{$colony_datum->{ships}{$glyph_transport_type}};
                if ($glyph_ship) {
                    $log->debug('Ship to transport glyphs is '.$glyph_ship->id);
                    # put the glyphs on the ship. It is a fairly safe assumption that the
                    # ship will have enough storage for glyphs (unless we have over 500 glyphs!)

#    print Dumper(@glyphs);
                    my @items = map { {type => 'glyph', glyph_id => $_->id} } @glyphs;
#    print Dumper(@items);
                    my $success = $trade_ministry->push_items($glyph_store_colony, \@items, {ship_id => $glyph_ship->id});
                    if (not $success) {
                        $log->error("Pushing to ".$glyph_store_colony->name." failed\n");
                    }
                }
                else {
                    $log->error('Cannot find a transport for glyphs');
                }
            }
            else {
                $log->info('No glyphs to transport');
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
                    my $success = $trade_ministry->push_items($excavator_launch_colony, \@items, {ship_id => $transport_ship->id});
                    if (not $success) {
                        $log->error("Pushing excavators to ".$excavator_launch_colony->name." failed. Do you have enough docks?");
                    }
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
# #################
# ##### TODO ###### DO this the same as build_excavators to save on API calls
# #################
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
    $log->info('Building probes at '.$colony->name);

#    print Dumper($colony_datum->{ships});

    my $colony_probes;
    if ($colony_datum->{ships}{probe}) {
        $colony_probes       = @{$colony_datum->{ships}{probe}};
    }
    else {
        $colony_probes = 0;
    }

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

    if ($to_build) {
        $log->info('We need to produce a further '.$to_build.' excavators');
    }
    else {
        $log->info('No more excavators need to be build at this time');
        return;
    }


    # Find all shipyards able to build excavators
    ##################
    # ##### NOTE ##### Could we do away with the 'buildable' and just attempt to build and catch the exception?
    ################## That would save us one API call per shipyard

    my @shipyards_buildable = (@all_ship_yards);

#    for my $shipyard (@all_ship_yards) {
#        my ($can_build_excavator) = grep {$_->type eq 'excavator' && $_->can_build} @{$shipyard->buildable};
#        if ($can_build_excavator) {
#            if ($shipyard->docks_available) {
#                push @shipyards_buildable, $shipyard;
#            }
#        }
#    }

    # Order all shipyards by the build queue size (increasing) which are below the max build queue size
    my @shipyards_sorted;
    for my $shipyard (sort {$a->number_of_ships_building <=> $b->number_of_ships_building} @shipyards_buildable) {
        $log->debug("Shipyard on colony ".$shipyard->colony->name." plot ".$shipyard->x."/".$shipyard->y." has ".$shipyard->number_of_ships_building." ships building");
        if ($shipyard->number_of_ships_building < $shipyard_max_builds) {
            push @shipyards_sorted, {shipyard => $shipyard, building => $shipyard->number_of_ships_building};
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
        for my $shipyard_hash (@shipyards_sorted) {

            my $shipyard = $shipyard_hash->{shipyard};
            # Ignore shipyards previously flagged as not being able to build
            next SHIPYARD if $cant_build_at->{$shipyard->id};

            if ($min_free < $shipyard_hash->{building}) {
                # start again at the beginning of the shipyard list
                $log->debug('Start building at the first shipyard again');
                $min_free++;
                next EXCAVATOR;
            }

            # then build a ship
            $log->debug("Building ship at shipyard ".$shipyard->colony->name." ".$shipyard->x."/".$shipyard->y." min_free = $min_free ships_building = ".$shipyard_hash->{building});
            if ( ! $shipyard->build_ship('excavator') ) {
                # We can't build at this shipyard any more
#                $shipyard->refresh;
                $cant_build_at->{$shipyard->id} = 1;
                next SHIPYARD;
            }
            $shipyard_hash->{building}++;
#            $shipyard->refresh;

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
#        prefetch    => {to_star => 'probe_visits'},
        order_by    => 'distance',
    });

DISTANCE:
    while (my $distance = $distance_rs->next) {
        $star = $distance->to_star;

        # For now, ignore any stars we have previously probed. Later on
        # we will have to check for a date > 30 days ago
        if ($star->probe_visits->count) {
#            $log->info("We visited star ".$star->name." previously");
            my @visits = $star->probe_visits->all;
            @visits = sort {$a->on_date cmp $b->on_date} @visits;
            for my $visit (@visits) {
                $log->info("Previously visited ".$star->name." on ".$visit->on_date);
            }
            next DISTANCE;
        }

        # ############
        # ### NOTE ### Is there any reason to think a star would *not* be probeable by a probe?
        ############## we could save on the call to get_available and assume any star is probeable

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
