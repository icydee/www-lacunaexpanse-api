#!/home/icydee/localperl/bin/perl

# Manage Glyphs
#
use strict;
use warnings;

use FindBin qw($Bin);
#use FindBin::lib;
use lib "$Bin/../lib";

use Log::Log4perl;
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../glyphs.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');
    $log->info('Program start');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");
    my $glyph_config    = YAML::Any::LoadFile("$Bin/../glyphs.yml");

    print Dumper($glyph_config);

    # Calculate tasks
    my $now             = DateTime->now;
    my $current_day     = $now->dow - 1;            # 0 = Monday
    my $current_hour    = $current_day * 24 + $now->hour;

    # Tasks to do at each colony on hour number
    my $tasks = {
        0.0  => \&_start_glyph_search,
        0.1  => \&_transport_glyphs_and_plans,
        0.2  => \&_build_probes,
	0.3  => \&_build_excavators,
	3.0  => \&_send_probes,
	5.0  => \&_send_excavators,
    };

    my $api = WWW::LacunaExpanse::API->new({
		    uri         => $my_account->{uri},
		    username    => $my_account->{username},
		    password    => $my_account->{password},
		    debug_hits  => $my_account->{debug_hits},
		    });

COLONY:
    for my $colony_name (keys %{$glyph_config->{excavator_colonies}}) {
	    my $config = $glyph_config->{excavator_colonies}{$colony_name};
	    print "Processing colony $colony_name\n";
	    my $base_hour = $config->{base_hour};
	    if (! defined $base_hour) {
		    $log->fatal("Config error: no base_hour defined for colony $colony_name");
	    }
	    my $task_hour = ($config->{base_hour} + $current_hour) % 7;

	    my @current_tasks   = grep { int($_) == $task_hour } sort keys %$tasks;

	    if ( ! @current_tasks ) {
		    $log->info("Nothing to do at colony $colony_name on task hour $task_hour");
		    next COLONY;
	    }
	    $log->info("Processing colony $colony_name on task hour $task_hour");

# Get some basic information about the colony.
	    my $empire = $api->my_empire;
	    my ($colony) = $empire->find_colony($colony_name);
	    if ( ! $colony ) {
		    $log->fatal('Cannot find colony name $colony_name\n");
	    }
	    my $archaeology = $colony->archaeology;
	    my $space_port  = $colony->space_port;
	    my $shipyard    = $colony->shipyard;
	    my $observatory = $colony->observatory;
	    my $trade_min   = $colony->trade_ministry;

	    for my $key (@current_tasks) {

		    &{$tasks->{$key}}({
				    api             => $api,
				    schema          => $schema,
				    config          => $glyph_config,
				    colony          => $colony,
				    archaeology     => $archaology,
				    space_port      => $space_port,
				    shipyard        => $shipyard,
				    observatory     => $observatory,
				    trade_min       => $trade_min,
				    });
	    };
    }
      }


####################################################################################
### Send probes out to new stars                                                 ###
####################################################################################

sub _send_probes {
	my ($args) = @_;

	my $log                 = Log::Log4perl->get_logger('MAIN::_send_probes');
	$log->info('_send_probes');

	my $config              = $args->{config};
	my $colony              = $args->{colony};

	$log->info('Sending probes from colony '.$colony->name);
	my $space_port          = $colony->space_port;
	my $observatory         = $colony->observatory;
	my $schema              = $args->{schema};
	my $api                 = $args->{api};

	my @probes_docked       = $space_port->all_ships('probe', 'Docked');
	my @probes_travelling   = $space_port->all_ships('probe', 'Travelling');

	my $centre_star = $api->find({ star => $colony->star->name }) || die "Cannot find star (".$colony->star->name,")";

# Max number of probes we can send is the observatory max_probes minus observatory probed_stars
# minus the number of travelling probes.
#
	my $observatory_probes_free = $observatory->max_probes - $observatory->count_probed_stars - scalar @probes_travelling;

	$log->debug("There are $observatory_probes_free slots available on colony ".$colony->name);
	$log->debug("There are ".scalar(@probes_docked)." docked probes on colony ".$colony->name);

	my $max_probes_to_send = min(scalar(@probes_docked), $observatory_probes_free);
PROBE:
	while ($max_probes_to_send) {

		my $probe = pop @probes_docked;

		my $probeable_star = _next_star_to_probe($schema, $args->{config}, $space_port, $observatory, $centre_star);
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

	my $colony              = $args->{colony};
	my $observatory         = $args->{observatory};
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
					$trade_ministry->push_items($glyph_store_colony, \@items, {ship_id => $glyph_ship->id});
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
	my $colony = $args->{colony};
	$log->info('_build_probes at colony'.$colony->name);

	my $config              = $args->{config};
	my $colony_config       = $config->{excavator_colonies}{$colony->name};

# Get all ship-yards at this colony
	my @ship_yards          = @{$colony->building_type('Shipyard')};

# Get all probes
	my @colony_probes       = $colony->all_ships('probe');
	$log->info('There are currently '.scalar @colony_probes.' probes building, docked or travelling on '.$colony->name);

	my $to_build            = $colony_config->{max_probes} - @colony_probes;
	my $max_build_level     = $colony_config->{max_ship_build};

	if ($to_build <= 0) {
		$log->info('We have enough probes, no need to build more just yet');
		return;
	}
	$log->info('We need to build a further '.$to_build.' probes');

	my $cant_build_at;           # if true, we can't build any more ships at this shipyard
		my $ships_building_at;       # number of ships building at a shipyard
		my $build_level = 1;

	for my $shipyard (@ship_yards) {
		$ships_building_at->{$shipyard->id} = $shipyard->number_of_ships_building;
	}

BUILD:
	while ($to_build && $build_level < $max_build_level) {
		my $at_least_one_built;

SHIPYARD:
		for my $shipyard (@ship_yards) {

# Ignore shipyards previously flagged as not being able to build
			next SHIPYARD if $cant_build_at->{$shipyard->id};

			if ($ships_building_at->{$shipyard->id} < $build_level) {
# Build a probe here

				$log->info('Building '.$ships_building_at->{$shipyard->id}.' ships at shipyard '.$shipyard->colony->name.' '.$shipyard->x.'/'.$shipyard->y);

				if ( ! $shipyard->build_ship('probe') ) {
# We can't build at this shipyard any more
#                    $shipyard->refresh;
					$cant_build_at->{$shipyard->id} = 1;
					next SHIPYARD;
				}
#                $shipyard->refresh;
				$to_build--;
				$at_least_one_built = 1;
				$ships_building_at->{$shipyard->id}++;
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
# to less than or equal to the config 'max_ship_build'.
#
# You only need to keep the queues full enough so that it is still working
# the next time this routine is called
#


sub _build_excavators {
	my ($args) = @_;

        my $log = Log::Log4perl->get_logger('MAIN::_build_excavators');
        my $colony = $args->{colony};
        $log->info('_build_excavators at colony'.$colony->name);

        my $config              = $args->{config};
        my $colony_config       = $config->{excavator_colonies}{$colony->name};

        # Get all ship-yards at this colony
        my @ship_yards          = sort {$a->id <=> $a->b} @{$colony->building_type('Shipyard')};

        # remove shipyards we need to keep free;
        for (1..$colony_config->{free_shipyards}) {
            pop @ship_yards;
        }

        # Get all excavators
        my @colony_excavators   = $colony->all_ships('excavator');
        $log->info('There are currently '.scalar @colony_excavators.' excavators building, docked or travelling on '.$colony->name);

        my $max_ship_build      = $colony_config->{max_ship_build};
        my $to_build            = $colony_config->{max_excavators} - scalar @colony_excavators;

	if ($to_build) {
            $log->info('We need to produce a further '.$to_build.' excavators');
	}
	else {
            $log->info('No more excavators need to be build at this time on colony '.$colony->name);
            return;
	}

	my @shipyards_buildable = (@all_ship_yards);

        # Order all shipyards by the build queue size (increasing) which are below the max build queue size
	my @shipyards_sorted;
	for my $shipyard (sort {$a->number_of_ships_building <=> $b->number_of_ships_building} @shipyards {
       	    $log->debug("Shipyard on colony ".$shipyard->colony->name." plot ".$shipyard->x."/".$shipyard->y." has ".$shipyard->number_of_ships_building." ships building");
	    if ($shipyard->number_of_ships_building < $max_ship_build) {
                push @shipyards_sorted, {shipyard => $shipyard, building => $shipyard->number_of_ships_building};
             }
        }

        # Distribute the building among those shipyards that can build
        # since the shipyards are sorted by the number of ships building we will have patterns like
        # 0,0,0,1,2,2,5 for the number of ships building
        # we need to make several passes through the data so the ships are built in the shortest queues first
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
                    $cant_build_at->{$shipyard->id} = 1;
                    next SHIPYARD;
                }
                $shipyard_hash->{building}++;
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


### If we have no 'distance' entries for this star, we need to populate
### the database with them.
	if ($schema->resultset('Distance')->search({from_id => $centre_star->id})->count == 0) {
# Calculate the distance from centre_star to all other stars and put in database
	}

# Find the closest star, over the specified distance, that we have not visited in the last 30 days
	my $distance_rs = $schema->resultset('Distance')->search_rs({
			from_id             => $centre_star->id,
			distance            => {'>', $distance},
			last_probe_visit    => {'<', $thirty_days_ago},
			}
			,{
			order_by    => 'distance',
			});

	my $star = $distance->to_star;
	my $now = WWW::LacunaExpanse::API::DateTime->now;

# Update the database, so we don't send one there again in the next 30 days
	$distance->last_probe_visit($now);

# Also record all visits
	$schema->resultset('ProbeVisit')->create({
			star_id     => $star->id,
			on_date     => $now,
			});

	return $star;
}

1;
