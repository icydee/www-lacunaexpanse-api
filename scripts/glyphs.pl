#!/home/icydee/localperl/bin/perl

# Manage Glyphs
#
use strict;
use warnings;

use FindBin qw($Bin);
use FindBin::libs;

use Log::Log4perl;
use Data::Dumper;
use DateTime;
use DateTime::Precise;
use List::Util qw(min max);
use YAML::Any;

use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::DB;

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../glyphs.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');
    $log->info('Program start');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");
    my $glyph_config    = YAML::Any::LoadFile("$Bin/../glyphs_new.yml");
    my $mysql_config    = YAML::Any::LoadFile("$Bin/../mysql.yml");

    my $now             = DateTime->now;
    my $current_day     = $now->dow - 1;     # 0 == Monday
    my $current_hour    = $current_day * 24 + $now->hour;

#$current_hour = 14;

    $log->debug("Current hour is $current_hour");
    my $something_to_do;

    my $tasks_to_do;
    # Do the empire wide checks first
    my $empire_config = $glyph_config->{empire};
    my @task_hour_keys = grep {$_ =~ /every_(\d+)_hours/} keys %{$empire_config};
    $log->debug("Empire task hours ".join(' - ', @task_hour_keys));
    my $base_hour = $empire_config->{base_hour} || 0;
    my @empire_tasks;
    for my $task_key (@task_hour_keys) {
        my ($hour) = $task_key =~ /every_(\d+)_hour/;
        if (($current_hour - $base_hour) % $hour == 0) {
            push @empire_tasks, @{$empire_config->{"every_${hour}_hours"}};
            $something_to_do = 1;
        }
    }
    $log->debug("Empire tasks ".join(' - ', @empire_tasks));
    my $all_tasks->{empire} = \@empire_tasks;

    # Now see if there are any colony tasks for this hour
    my $colony_config = $glyph_config->{colony};

COLONY:
    for my $colony_name (keys %$colony_config) {
        my $config = $colony_config->{$colony_name};
        print "Processing colony $colony_name\n";
        my $base_hour = $config->{base_hour} || 0;

        # Get the tasks for this colony
        @task_hour_keys = grep {$_ =~ /every_(\d+)_hours/} keys %{$config};
        $log->debug("Colony $colony_name task hours ".join(' - ', @task_hour_keys));
        my @colony_tasks;
        for my $task_key (@task_hour_keys) {
            my ($hour) = $task_key =~ /every_(\d+)_hour/;
            $log->debug("Colony $colony_name task hour $hour");
            if (($current_hour - $base_hour) % $hour == 0) {
                $log->debug("current hour $current_hour, hour = $hour");
                push @colony_tasks, @{$config->{"every_${hour}_hours"}};
                $something_to_do = 1;
            }
        }
        $log->debug("Colony $colony_name tasks ".join(' - ', @colony_tasks));
        $all_tasks->{colonies}{$colony_name} = \@colony_tasks;
    }

    if (! $something_to_do) {
        $log->info("Nothing to do at task hour $current_hour");
        exit;
    }

    my $schema = WWW::LacunaExpanse::DB->connect(
        $mysql_config->{dsn},
        $mysql_config->{username},
        $mysql_config->{password},
        {AutoCommit => 1, PrintError => 1},
    );

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
        debug_hits  => $my_account->{debug_hits},
    });

    my $subroutine_ref = {
        arch_min_search             => \&_arch_min_search,
        save_email                  => \&_save_email,
        build_ships                 => \&_build_ships,
        build_excavators            => \&_build_excavators,
        build_probes                => \&_build_probes,
        send_probes                 => \&_send_probes,
        send_excavators             => \&_send_excavators,
        transport_glyphs_and_plans  => \&_transport_glyphs_and_plans,
        transport_excavators        => \&_transport_excavators,
    };

    # Do the empire wide tasks first.
    my $empire = $api->my_empire;
    TASK:
    for my $task (@{$all_tasks->{empire}}) {
        my $subroutine = $subroutine_ref->{$task};
        if ( ! $subroutine ) {
            $log->error("Unknown Empire task: '$task'");
            next TASK;
        }
        &$subroutine({
            config      => $glyph_config,
            schema      => $schema,
            api         => $api,
            empire      => $empire,
        });
    }

    # Do all the colony tasks
COLONY:
    for my $colony_name (sort keys %{$all_tasks->{colonies}}) {
        print "Tasks for colony $colony_name\n";
        my ($colony) = @{$empire->find_colony($colony_name)};
        if ( ! $colony ) {
            $log->error("Cannot find colony '$colony_name'");
            next COLONY;
        }
        TASK:
        for my $task (@{$all_tasks->{colonies}{$colony_name}}) {
            my $subroutine = $subroutine_ref->{$task};
            if ( ! $subroutine ) {
                $log->error("Unknown Colony task: '$task'");
                next TASK;
            }
            &$subroutine({
                config      => $glyph_config,
                schema      => $schema,
                api         => $api,
                empire      => $empire,
                colony      => $colony,
            });
        }
    }
    $log->info("Program completed");
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

    my $centre_star = $api->find({ star => $colony->star->name });
    if (! $centre_star) {
        $log->error("Cannot find centre star ".$colony->star->name);
        return;
    }

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

# Save email and archive some of it
#
sub _save_email {
    my ($args) = @_;

    my $log         = Log::Log4perl->get_logger('MAIN::_save_email');
    $log->info('_save_email');

    my $my_empire   = $args->{empire};
    my $schema      = $args->{schema};
    my $api         = $args->{api};
    my $config      = $args->{config};

    my $inbox       = $api->inbox;
    my @archive_titles = @{$config->{empire}{archive_titles}};

    my @archive_messages;
    my $message_count = 0;

    $inbox->reset_message;
    my @all_messages = $inbox->all_messages;

    MESSAGE:
    # Read all messages, oldest first
    for my $message (reverse @all_messages) {
        $log->info($message->date."\t".$message->subject);

        # Do we already have the message?
        my ($db_message) = $schema->resultset('Message')->search({
            server_id       => 1,
            empire_id       => $my_empire->id,
            message_id      => $message->id,
        });
        if (! $db_message ) {
            # Not already saved, so save it.
            eval {
               my $db_message = $schema->resultset('Message')->create({
                   server_id       => 1,
                   empire_id       => $my_empire->id,
                   message_id      => $message->id,
                   subject         => $message->subject,
                   on_date         => $message->date,
                   sender          => $message->from,
                   sender_id       => $message->from_id,
                   recipient       => $message->to,
                   recipient_id    => $message->to_id,
                   has_read        => $message->has_read,
                   has_replied     => $message->has_replied,
                   has_archived    => $message->has_archived,
                   in_reply_to     => $message->in_reply_to,
                   body_preview    => $message->body_preview,
                   body            => $message->body,
               });
            };
            if ($@) {
                my $e = $@;
                $log->info("#### $e ####");
                if ($e =~ m/Duplicate entry/) {
                    # then we have already stored it, don't worry
                }
                else {
                    $log->error("Cannot save record. $e");
                    last MESSAGE;
                }
            }
        }
        # Archive certain message titles immediately.
        if ($message->from_id == $my_empire->id && $message->to_id == $my_empire->id) {
            if (grep {$_ eq $message->subject} @archive_titles) {
                push @archive_messages, $message->id;
            }
        }
        if (++$message_count == 20) {
            $message_count = 0;
            $log->debug("#### ARCHIVING MESSAGES ####");
            $inbox->archive_messages(\@archive_messages);
            undef @archive_messages;
        }
    }

    # archive any remaining messages
    if (@archive_messages) {
        $log->debug("#### ARCHIVING MESSAGES ####");
        $inbox->archive_messages(\@archive_messages);
    }
}


# Send excavators out to bodies
#
sub _send_excavators {
    my ($args) = @_;

    my $log             = Log::Log4perl->get_logger('MAIN::_send_excavators');
    $log->info('_send_excavators');

    my $colony          = $args->{colony};
    my $empire          = $args->{empire};
    my $schema          = $args->{schema};
    my $api             = $args->{api};
    my $config          = $args->{config};

    my $colony_config   = $config->{colony}{$colony->name};
    $log->info("Sending excavators out from colony ".$colony->name);

    my $space_port      = $colony->space_port;
    if ( ! $space_port ) {
        $log->error('There is no space port');
        return;
    }

    my @excavators      = $space_port->all_ships('excavator','Docked'); #<<<1+>>>#
    if ( ! @excavators) {
        $log->warn('There are no excavators to send');
        return;
    }

    if ($colony_config->{dont_use_probes}) {
        $log->info("Sending excavators without using probes method");
        my ($next_excavated_star)   = $schema->resultset('Config')->search({name => 'next_excavated_star'});
        my ($next_excavated_orbit)  = $schema->resultset('Config')->search({name => 'next_excavated_orbit'});

        my $fail_count = 0;
        EXCAVATOR:
        while (@excavators) {
            # get the x/y co-ordinate of the body
            my $star = $schema->resultset('Star')->find({server_id => 1, star_id => $next_excavated_star->val}); # we assume that id's are consecutive
            my $offsets = {
                1   => {x =>  1, y =>  2},
                2   => {x =>  2, y =>  1},
                3   => {x =>  2, y => -1},
                4   => {x =>  1, y => -2},
                5   => {x => -1, y => -2},
                6   => {x => -2, y => -1},
                7   => {x => -2, y =>  1},
                8   => {x => -1, y =>  2},
            };
            my $x = $star->x + $offsets->{$next_excavated_orbit->val}{x};
            my $y = $star->y + $offsets->{$next_excavated_orbit->val}{y};
            my $first_excavator = $excavators[0];

            # NOTE: send_ship will normally fail because of there being no body at the co-ordinates
            # however it could fail because of the 10k RPC limit in which case we need to handle
            # it differently.
            my $success = $space_port->send_ship($first_excavator->id, {x => $x, y => $y}); #<<<1>>>#
            if ($success) {
                $fail_count = 0;
                shift @excavators;
            }
            else {
                $fail_count++;
                if ($fail_count == 30) {
                    # Then it is not likely to be because we can't visit the body.
                    # it is more likely a server or RPC error, so terminate now
                    last EXCAVATOR;
                }
            }
            if ($next_excavated_orbit->val == 8) {
                $next_excavated_orbit->update({val => 1});
                $next_excavated_star->update({val => $next_excavated_star->val + 1});
            }
            else {
                $next_excavated_orbit->update({val => $next_excavated_orbit->val + 1});
            }
        }
    }
    else {
        $log->info("Sending excavators having first sent probes");
        my $observatory = $colony->observatory;

        $observatory->refresh;
        my $probed_star = $observatory->next_probed_star;

        if (! $probed_star) {
            $log->warn('There are no more probed stars');
            return;
        }

        my ($db_star, $db_body_rs, $db_body);

        _save_probe_data($schema, $api, $probed_star);
        $db_star        = $schema->resultset('Star')->find($probed_star->id);
        $db_body_rs     = $db_star->bodies;
        $db_body        = $db_body_rs->first;

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
            }
        $db_body = $db_body_rs->next;
        }
    }
}


# start a glyph search
# The current algorithm tries to maximise the number of Halls
# if you want it to do anything else please do so via the YAML configuration
#
sub _arch_min_search {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_start_glyph_search');

    my $config          = $args->{config};
    my $algorithm       = $config->{empire}{glyph_search_algo};
    my $colony          = $args->{colony};
    my $empire          = $args->{empire};
    my $schema          = $args->{schema};

    # Find out if any colonies want to to archaeology ministry searches for ore.
    my $do_arch_searches;
    COLONY:
    for my $col (@{$empire->colonies}) {
        if ($config->{colony}{$col->name}{arch_min_search}) {
            $do_arch_searches = 1;
            last COLONY;
        }
    }
    if ( ! $do_arch_searches ) {
        $log->warn("No colonies want to do archaeology ministry searches for ore");
        return;
    }

    # Locate all archaeology ministries in the empire
    $log->info("At least one colony wants to do an archaeology search");
    $log->info("Locate all archaeology ministries in the empire, to see what glyphs we have");
    my @all_archaeology;
    for my $col (@{$empire->colonies}) {
        my $arch = $col->archaeology;
        if ($arch) {
            push @all_archaeology, $arch;
        }
    }


    ##### NOTE #####
    ################
    # Something here is doing a call to get_glyphs twice for each arch min
    ################

    # Get the total of all glyphs at all archaeology ministries
    my @all_glyphs;
    my $combined_glyphs;
    for my $glyph_name (WWW::LacunaExpanse::API::Ores->ore_names) {
        $combined_glyphs->{$glyph_name} = 0;
    }
    for my $arch (@all_archaeology) {
        my $glyphs = $arch->get_glyphs;
        push @all_glyphs, @$glyphs;

        for my $glyph (@$glyphs) {
            $combined_glyphs->{$glyph->type}++;
        }
    }

    # Put all glyphs owned into the database
    my $now = WWW::LacunaExpanse::API::DateTime->now;
    for my $glyph (@all_glyphs) {
        my $db_glyph = $schema->resultset('Glyph')->find({
            server_id   => 1,
            empire_id   => $empire->id,
            glyph_id    => $glyph->id
        });
        if ( ! $db_glyph) {
            # We have not previously inserted it, so save it now
            $db_glyph = $schema->resultset('Glyph')->create({
                server_id   => 1,
                empire_id   => $empire->id,
                glyph_id    => $glyph->id,
                glyph_type  => $glyph->type,
                found_on    => $now,
            });
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

    # Now set each (enabled) archaeology ministry searching for glyphs

ARCHAEOLOGY:
    for my $archaeology (@all_archaeology) {

        # Only search if the config says to do so
        next ARCHAEOLOGY unless $config->{colony}{$archaeology->colony->name}{arch_min_search};

        # Now start a search at this ministry based on the glyph sort order
        $log->info("Searching archaeology ministry ".$archaeology->x.":".$archaeology->y." on colony ".$archaeology->colony->name);
        my @ores_for_processing = @{$archaeology->get_ores_available_for_processing};
        $log->info("Ores for processing = ".join('-', map {$_->type} @ores_for_processing));
        my $done_search = 0;

        ORE:
        for my $ore_type (@glyph_sort_order) {
            my $do_search = grep {$ore_type eq $_->type} @ores_for_processing;

            if ($do_search) {
                $done_search = 1;
                if ($archaeology->search_for_glyph($ore_type)) {
                    $log->info("Searching for glyph type '$ore_type' at colony ".$archaeology->colony->name);
                }
                else {
                    $log->info("Cannot search for glyphs at arch min. Perhaps it is busy");
                }
                last ORE;
            }
        }
        if (! $done_search) {
            $log->warn("No ores for glyph searching at colony ".$archaeology->colony->name);
        }
    }
}

# Transport glyphs and plans to the storage colony
#
sub _transport_glyphs_and_plans {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_transport_glyphs');
    $log->info('_transport_glyphs');

    my $colony          = $args->{colony};
    my $empire          = $args->{empire};
    my $config          = $args->{config};
    my $colony_config   = $config->{colony}{$colony->name};
    my $glyph_colony    = $colony_config->{glyph_colony};
    if ($glyph_colony) {
        ($glyph_colony) = @{$empire->find_colony($glyph_colony)};
        $log->debug("Glyph colony is ".$glyph_colony->name);
    }
    my $plan_colony     = $colony_config->{plan_colony};
    if ($plan_colony) {
        ($plan_colony)  = @{$empire->find_colony($plan_colony)};
        $log->debug("Plan colony is ".$plan_colony->name);
    }

    # Get the trade ministry
    my $trade_ministry = $colony->trade_ministry;
    if (! $trade_ministry) {
        $log->warning('There is no trade ministry on '.$colony->name);
        return;
    }

    # Get the Space Port
    my $space_port = $colony->space_port;

    # Get the glyph/plan transport ship(s)
    my (@glyph_ships, @plan_ships);
    my @all_ships = $space_port->all_ships;

    if ($glyph_colony && $glyph_colony->name ne $colony->name) {
        $log->debug("Checking for docked glyph ships");
        (@glyph_ships) = grep {$_->name eq $config->{empire}{glyph_ship_name} && $_->task eq 'Docked'} @all_ships;
    }
    if ($plan_colony && $plan_colony->name ne $colony->name) {
        $log->debug("Checking for docked plan ships");
        (@plan_ships) = grep {$_->name eq $config->{empire}{plan_ship_name} && $_->task eq 'Docked'} @all_ships;
    }

    if (! @glyph_ships && $glyph_colony) {
        $log->error("There are no glyph ships named ".$config->{empire}{glyph_ship_name}." on colony ".$colony->name);
    }
    if (! @plan_ships && $plan_colony) {
        $log->error("There are no plan ships named ".$config->{empire}{plan_ship_name}." on colony ".$colony->name);
    }
    # check for glyphs
    $log->debug("Checking for glyphs to transport on ".$colony->name);

    my @glyphs = @{$trade_ministry->get_glyphs};
    if (@glyphs) {
        $log->info("There are ".scalar(@glyphs)." glyphs to transport");
    }

    my @plans = @{$trade_ministry->plans};
    if (@plans) {
        $log->info("There are ".scalar(@plans)." plans to transport");
    }

    if (@plans && $plan_colony && @plan_ships < 1) {
        $log->error("There are no ships named ".$config->{empire}{plan_ship_name}." docked to transport the plans");
    }

    if (@glyphs && $glyph_colony && @glyph_ships < 1) {
        $log->error("There are no ships named ".$config->{empire}{glyph_ship_name}." docked to transport the glyphs");
    }
    $log->info("There are ".scalar(@glyph_ships)." glyph ships");
    $log->info("There are ".scalar(@plan_ships)." plan ships");

    # put glyphs onto glyph ships
    my $storage_used = 0;
    while (@glyphs && @glyph_ships && $glyph_colony) {
        my $glyph_ship = shift @glyph_ships;
        # max glyphs we can put on this ship
        my $max_glyphs = int($glyph_ship->hold_size / @glyphs) * 100;
        my @glyphs_to_transport = splice @glyphs, 0, $max_glyphs;
        my @items = map { {type => 'glyph', glyph_id => $_->id} } @glyphs_to_transport;
        $trade_ministry->push_items($glyph_colony, \@items, {ship_id => $glyph_ship->id});
    }

    # put plans onto plan ships
    while (@plans && @plan_ships && $plan_colony) {
        $log->debug("Transporting Plans");
        my $plan_ship = shift @plan_ships;
        # max plans we can put on this ship
        my $max_plans = int($plan_ship->hold_size / @plans) * $trade_ministry->cargo_space_used_each;
        my @plans_to_transport = splice @plans, 0, $max_plans;
        my @items = map { {type => 'plan', plan_id => $_->id} } @plans_to_transport;
        $trade_ministry->push_items($plan_colony, \@items, {ship_id => $plan_ship->id});
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

# Build more Probes on our colony
#
#
# This is to ensure that the observatory is kept fully occupied since
# the excavators will abandon probes once they have excavated all available
# bodies in a system.
#
# Leave some shipyards unused by this script so they can be used manually
#
sub _build_probes {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_build_probes');
    my $colony = $args->{colony};
    $log->info('_build_probes at colony '.$colony->name);

    my $config              = $args->{config};
    my $colony_config       = $config->{colony}{$colony->name};

    if ($colony_config->{dont_use_probes}) {
        $log->info('We don\'t use probes at colony '.$colony->name);
        return;
    }

    # Get all ship-yards at this colony
    my @ship_yards          = sort {$a->id <=> $b->id} @{$colony->building_type('Shipyard')};
    # shift off the shipyards we want to reserve for manual use. By sorting by ID these are always the same one's
    splice @ship_yards, 0, $colony_config->{free_shipyards};

    # Get all probes
    my $space_port          = $colony->space_port;
    my @colony_probes       = $space_port->all_ships('probe');
    $log->info('There are currently '.scalar @colony_probes.' probes building, docked or travelling on '.$colony->name);

    my $to_build            = $colony_config->{max_probes} - @colony_probes;
    my $max_build_level     = $colony_config->{max_ship_build};

    if ($to_build <= 0) {
        $log->info('We have enough probes, no need to build more just yet');
        return;
    }
    $log->info('We need to build a further '.$to_build.' probes');

    my $cant_build_at;                  # if true, we can't build any more ships at this shipyard
    my $ships_building_at;              # number of ships building at a shipyard
    my $build_level = 1;

    for my $shipyard (@ship_yards) {
        my $ships_building = $shipyard->number_of_ships_building;
        if ($ships_building == 0) {
            # then we are not using the full capacity of our shipyards.
        }
        elsif ($ships_building > 1) {
            # then we are stacking too many ships at our shipyards
        }
        $ships_building_at->{$shipyard->id} = $ships_building;
    }

    $log->info("to_build $to_build, build_level $build_level, max_build_level $max_build_level");
BUILD:
    while ($to_build && $build_level <= $max_build_level) {
        my $at_least_one_built;

SHIPYARD:
        for my $shipyard (@ship_yards) {

            # Ignore shipyards previously flagged as not being able to build
            # NOTE TO SELF. Presumably, if we can't build at one shipyard, we can't build at any
            next SHIPYARD if $cant_build_at->{$shipyard->id};

            if ($ships_building_at->{$shipyard->id} < $build_level) {
                # Build a probe here

                $log->info('Building '.$ships_building_at->{$shipyard->id}.' ships at shipyard '.$shipyard->colony->name.' '.$shipyard->x.'/'.$shipyard->y);

                if ( ! $shipyard->build_ship('probe') ) {
                    # We can't build at this shipyard any more
                    $cant_build_at->{$shipyard->id} = 1;
                    # NOTE TO SELF. Presumably, if we can't build at one shipyard on this colony, we can't build at any
                    # in which case this next line should be 'last BUILD'?
                    next SHIPYARD;
                }
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
    if ($to_build) {
        # then we don't have enough capacity at our shipyards
    }
}


# Generic build ships routine.
#
# allocate a specified number of shipyards to each ship type.
# and fill each ship build queue to the level of the building.
# If no more ships of a particular type are needed, use those
# shipyards for the next priority of ship.
#
sub _build_ships {
    my ($args) = @_;

    my $log             = Log::Log4perl->get_logger('MAIN::_build_ships');
    my $colony          = $args->{colony};
    $log->info('_build_ships at colony '.$colony->name);

    my $config          = $args->{config};
    my $colony_config   = $config->{colony}{$colony->name}; 

    # Get all shipyards at this colony
    # We might want to sort by largest building level first, then ID so a level 22 shipyard comes first
    my @ship_yards      = sort {$b->level <=> $a->level && $a->id <=> $b->id} @{$colony->building_type('Shipyard')};
    $log->info("There are ".scalar(@ship_yards)." ship yards on colony ".$colony->name);

    # Get all ships at this colony
    my $space_port      = $colony->space_port;
    my @all_ships       = $space_port->all_ships;

    # Get the shipyards at this colony
    my @ship_builds     = @{$colony_config->{ship_build}};
    my $quick_ship_yard;
    if ($colony_config->{quick_ship_build}) {
        $quick_ship_yard = shift @ship_yards;
    }
    # Remove shipyards we want to keep clear for personal use
    splice @ship_yards, 0, $colony_config->{free_shipyards};

    my $ship_yard       = shift @ship_yards;
    my $available_docks = $ship_yard->level - $ship_yard->ships_building;

    SHIP:
    for my $ship_build (@ship_builds) {
        my $ships_now   = grep {$_->type eq $ship_build->{type}} @all_ships;
        my $ships_needed = $ship_build->{quota} - $ships_now;
        if ($ships_needed > 0) {
            # loop around filling each shipyard in turn until there are either no
            # more shipyards or we don't need any more ships

            SHIP_YARD:
            while ($ships_needed && $ship_yard) {
                # quick_ship_build means we have a level 22 shipyard, and level 7 species manufacturing affinity
                # so do all ship building at the level 22 shipyard
                
                if ($available_docks <= 0) {
                    my $ship_yard = shift @ship_yards;
                    last SHIP unless $ship_yard;
                    next SHIP_YARD;
                }
                if ($quick_ship_yard) {
                    $log->debug("Building ship type ".$ship_build->{type}." at level 22 ship yard");
                    last SHIP unless $quick_ship_yard->build_ship($ship_build->{type});
                }
                else {
                    $log->debug("Building ship type ".$ship_build->{type}." at normal ship yard");
                    last SHIP unless $ship_yard->build_ship($ship_build->{type});
                }
                $available_docks--;
            }
        }
    }
}

# Build more excavators on this colony.
#
# Order the shipyards by build queue size (smallest first)
# Iterate through the shipyards adding one more excavator to each queue
# in a way that ensure that we level up all lower level queues
# so that they are all equal to or less than the 'max_ship_build' config
# value
#
# Ideally each queue should be just finishing it's last ship the next time
# this routine is called. If it is empty, we are not utilising our build
# capacity to it's maximum, if more than one, we are blocking the queue.
#
sub _build_excavators {
    my ($args) = @_;

    my $log = Log::Log4perl->get_logger('MAIN::_build_excavators');
    my $colony = $args->{colony};
    $log->info('_build_excavators at colony '.$colony->name);

    my $config              = $args->{config};
    my $colony_config       = $config->{colony}{$colony->name};
    my $free_shipyards      = $colony_config->{free_shipyards} || 0;
    my $max_ship_build      = $colony_config->{max_ship_build} || 0;
    my $max_excavators      = $colony_config->{max_excavators} || 0;

    # Get all ship-yards at this colony
    my @ship_yards          = sort {$a->id <=> $b->id} @{$colony->building_type('Shipyard')};

    $log->debug("keep $free_shipyards shipyards clear ");
    $log->debug("there are ".scalar @ship_yards." shipyards");
    # remove shipyards we need to keep free;
    splice @ship_yards, 0, $free_shipyards;
    $log->debug("there are ".scalar @ship_yards." shipyards we can use to build excavators");

    my $space_port          = $colony->space_port;

    # Get all excavators
    my @colony_excavators   = $space_port->all_ships('excavator');
    $log->info('There are currently '.scalar @colony_excavators.' excavators building, docked or travelling on '.$colony->name);

    my $to_build            = $max_excavators - scalar @colony_excavators;

    if ($to_build <= 0) {
        $log->info('No more excavators need to be build at this time on colony '.$colony->name);
        return;
    }
    $log->info('We need to produce a further '.$to_build.' excavators');

    my @shipyards_buildable = (@ship_yards);

    # Order all shipyards by the build queue size (increasing) which are below the max build queue size
    my @shipyards_sorted;
    for my $shipyard (sort {$a->number_of_ships_building <=> $b->number_of_ships_building} @ship_yards) {
        $log->debug("Shipyard on colony ".$shipyard->colony->name." plot ".$shipyard->x."/".$shipyard->y." has ".$shipyard->number_of_ships_building." ships building");
        if ($shipyard->number_of_ships_building < $max_ship_build) {
            push @shipyards_sorted, {shipyard => $shipyard, ships_building => $shipyard->number_of_ships_building, docks_max => $shipyard->level};
        }
    }

    # Distribute the building among those shipyards that can build
    # since the shipyards are sorted by the number of ships building we will have patterns like
    # 0,0,0,1,2,2,5 for the number of ships building
    # we can  make several passes through the data so the ships are built in the shortest queues first
    # taking into account those shipyards which can't build any more (due to lack of space or resources)
    # We don't bother taking into account of the build times of all the shipyards.
    #
    my $min_free = 0;
    my $cant_build_at;                  # hash of shipyards we can't build at
    EXCAVATOR:
    while ($to_build && $min_free < $max_ship_build) {

        my $at_least_one_built = 0;
        SHIPYARD:
        for my $shipyard_hash (@shipyards_sorted) {
            my $shipyard = $shipyard_hash->{shipyard};
            # Ignore shipyards previously flagged as not being able to build
            next SHIPYARD if $cant_build_at->{$shipyard->id};
            # Don't build more ships than the building level
#            $log->error("SHIPYARD LEVEL: ".$shipyard_hash->{docks_max});
#            $log->error("SHIPYARD BUILDING: ".$shipyard_hash->{ships_building});
            next SHIPYARD if $shipyard_hash->{ships_building} >= $shipyard_hash->{docks_max};

            if ($min_free < $shipyard_hash->{ships_building}) {
                # start again at the beginning of the shipyard list
                $log->debug('Start building at the first shipyard again');
                $min_free++;
                next EXCAVATOR;
            }

            # then build a ship
            $log->debug("Building excavator at shipyard ".$shipyard->colony->name." ".$shipyard->id." ".$shipyard->x."/".$shipyard->y." min_free = $min_free ships_building = ".$shipyard_hash->{ships_building});
            if ( ! $shipyard->build_ship('excavator') ) {
                # We can't build at this shipyard any more
                $cant_build_at->{$shipyard->id} = 1;
                # NOTE TO SELF. Presumably, if we can't build at this shipyard, we can't build at any shipyard
                # and so the next line should be 'last EXCAVATOR'
                last EXCAVATOR;
            }
            $shipyard_hash->{ships_building}++;
            $shipyard_hash->{docks_available}--;
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
    my $db_star = $schema->resultset('Star')->find({
        server_id   => 1,               # (I really must stop doing magic numbers!)
        star_id     => $probed_star->id,
    });

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

                # NOTE TO SELF. We must not consider Black Hole Generators that can
                # convert planets to asteroids.

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
        # TO BE DONE... Calculate the distance from centre_star to all other stars and put in database
    }

    my $thirty_days_ago = DateTime::Precise->new;
    $thirty_days_ago->dec_day(31);

    # Find the closest star, over the specified distance, that we have not visited in the last 30 days
    my $distance_rs = $schema->resultset('Distance')->search_rs({
        from_id             => $centre_star->id,
        distance            => {'>', $distance},
        last_probe_visit    => {'<', $thirty_days_ago},
    }
    ,{
        order_by    => 'distance',
    });

    $star = $distance->to_star;
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
