#!/home/icydee/localperl/bin/perl

# Script to send out probes.
#
# Send probes out to stars that have bodies that have never been visited by
# excavators, or bodies not visited by excavators in the last 30 days.
#
# Send probes out to stars never visited in increasing order of distance.
#
# Destroy oldest probes once they have been visited by an excavator
#
# NOTE: The 'excavate.pl' script will ensure that there are enough probes produced
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

#### Configuration ####
my $username                = 'icydee';
my $password                = 'secret';

my $uri                     = 'https://us1.lacunaexpanse.com';
my $dsn                     = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

my $probe_colony            = 'icydee 4';       # Colony to devote to sending out probes
my $centre_star_name        = 'Lio Easphai';    # Name of star to act as centre of search pattern
my $min_distance            = 500;              # Minimum distance to send out probes

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

my $colony = $api->find({ my_colony => $probe_colony });

print "Sending probes from my colony [".$colony->name."] ".$colony->x."/".$colony->y."\n";

my $centre_star = $api->find({ star => $centre_star_name }) || die "Cannot find star ($centre_star_name)";

my $observatory = $colony->observatory;
my $space_port  = $colony->space_port;

########################################################################
### Ensure we have calculated all the distances from the centre body ###
########################################################################

# We calculate the distance from the central star to all other stars in the
# universe and hold the distances in the SQL database. This makes it easier
# to determine the next closest star with a simple query
#
# NOTE: this can take a little while, but it is only needed once for each
# search loci.
#
my $distance_count  = $schema->resultset('Distance')->search({from_id => $centre_star->id})->count;
my $star_count      = $schema->resultset('Star')->search()->count;
#print "Distance_count=$distance_count star_count=$star_count\n";

if ($distance_count != $star_count) {
    # Re-initialise the distance table
    $schema->resultset('Distance')->search({from_id => $centre_star->id})->delete;
    my $star_rs = $schema->resultset('Star')->search_rs({});

    while (my $star = $star_rs->next) {
        my $distance = int(sqrt(($star->x - $centre_star->x)**2 + ($star->y - $centre_star->y)**2));
        $schema->resultset('Distance')->create({
            from_id     => $centre_star->id,
            to_id       => $star->id,
            distance    => $distance,
        });
        print "[".$star->id."]\tDistance to star ".$star->name." (".$star->x."|".$star->y.") is $distance\n" ;
    }
}

####################################################################
### Check all the probes currently registered by the observatory ###
####################################################################

# We may as well store the data for all the probes currently in the observatory
# and for any probes sent out manually
#

#goto RESCAN;    # JUST FOR TEST PURPOSES
print "Observatory has probed: [".$observatory->count_probed_stars."] stars.\n";

while (my $probed_star = $observatory->next_probed_star) {
    _save_probe_data($schema, $probed_star, 3);
}

# To keep it simple, this script handles all probes sent from this observatory.
# if you want to send out other probes, do so from another colony.

# To further keep it simple, even if a probe has been sent to a star by another
# colony or alliance member, we send another one anyway.

# This script is intended to be run continuously. To stop it hit ctrl-c
#
RESCAN:
while (1) {
    ##########################################################
    ### Delete probes where all bodies have been excavated ###
    ##########################################################

    my @stars = $schema->resultset('Star')->search({
        status      => 4,
    });

    for my $star_db (@stars) {
        $observatory->abandon_probe($star_db->id);
        $star_db->status(5);
        $star_db->update;
    }

    ####################################################################################
    ### See if there are any stars that are 'pending' that may have received a probe ###
    ####################################################################################

    # See if any probes previously in-transit have now arrived at their star

    my $db_star_rs = $schema->resultset('Star')->search_rs({
        status      => 1,
    });

    while (my $db_star = $db_star_rs->next) {
        print "Star ".$db_star->name." is pending\n";

        my ($star) = $api->find({star => $db_star->name });

        if (@{$star->bodies}) {
            # There are bodies, a probe must have arrived
            print "Retrieving probe data\n";
            _save_probe_data($schema, $star, 3);
        }
        else {
            # See if there are any incoming probes and when they arrive
            print "Checking for incoming probes\n";
            my $arrival_date = $star->check_for_incoming_probe;
            if ($arrival_date) {
                print "Probe will arrive at $arrival_date\n";
                # Push arrival time on the job queue
            }
            else {
                print "### The probe seems to have been lost! ###\n";
                $db_star->status(0);
                $db_star->update;
            }
        }
    }


    # Find any stars where all bodies have not been visited in the last 32 days
    @stars = $schema->resultset('Star')->search({
        status => [2,5],                        # another colony or probe deleted
    });

    my @probe_stars;
STARS:
    for my $star (@stars) {
        # Get all bodies for this star
        my @bodies = $star->bodies;
        my $now = WWW::LacunaExpanse::API::DateTime->now;
        my $thirty_two_days_ago = $now->copy;
        $thirty_two_days_ago = $thirty_two_days_ago - 32 * 24 * 60 * 60;
        my $newest_body_age = ''.$thirty_two_days_ago;

BODIES:
        for my $body (@bodies) {
            # If the body has an empire, skip it
            if ($body->empire_id) {
#                next BODIES;
            }
            # Get the latest excavation (if any) for this body
            my $excavation = $body->excavations->search({},{order_by => { -desc => 'on_date' }})->first;
            if ($excavation && $excavation->on_date > $newest_body_age) {
                $newest_body_age = $excavation->on_date;
            }
        }
        $newest_body_age = WWW::LacunaExpanse::API::DateTime->from_lacuna_email_string($newest_body_age);

#        print "star: ".$star->name." excavated $newest_body_age ago [$thirty_two_days_ago]\n";

        if ($newest_body_age <= $thirty_two_days_ago) {
            # Excavator sent more than 32 days ago, or not at all
#            print "Excavator sent more than 32 days ago to star ".$star->name."\n";
            push @probe_stars, $star;
        }
    }
    print "There are ".scalar(@probe_stars)." candidate stars to send probes to\n";

    # We can send a probe if we have one in the space port and there is a free slot in the observatory
    # Note.
    my $observatory_slots_free = $observatory->max_probes - $observatory->count_probed_stars;
    my @probes = grep {$_->task eq 'Docked'} $space_port->all_ships('probe');

PROBES:
    while (@probes) {
        print "There are ".scalar(@probes)." docked probes at the space port\n";
        if (@probe_stars) {
            print "There are probe_stars we can send a probe to\n";
            # We can send a probe back to a previously excavated star system

            my $distance_rs = $schema->resultset('Distance')->search_rs({
                from_id             => $centre_star->id,
                'to_star.status'    => 5,
                to_id               => [map {$_->id} @probe_stars],
#                distance            => {'>' => $min_distance},
                }
                ,{
                    join        => 'to_star',
                    order_by    => 'distance',
                });


            while (my $distance = $distance_rs->next) {
                my $star = $distance->to_star;

                print "get available ships for ".$star->name."\n";
                my $available_ships     = $space_port->get_available_ships_for({ star_id => $star->id });
                # If no available ships, contrary to there being probes available, this means
                # that there are probably probes in transit and the observatory is full

                my @available_probes    = grep {$_->type eq 'probe'} @$available_ships;
                if (@available_probes) {
                    print "AVAILABLE\n";
                }
                else {
                    print "LAST probes\n";
                    last PROBES;
                }

                my $probe               = $available_probes[0];
                if ($probe) {
                    print "Sending probe ID ".$probe->id." to star ".$star->name."\n";
                    my $arrival_time = $space_port->send_ship($probe->id, {star_id => $star->id});
                    # Mark the star as 'pending' the arrival of the probe
                    $star->status(1);
                    $star->update;
                    print "Probe will arrive at $arrival_time\n";
                    @probes = grep {$_->id ne $probe->id} @probes;
                    if (@probes) {
                        next PROBES;
                    }
                    else {
                        last PROBES;
                    }
                }
            }
        }
        else {
            # We have to send a probe to a new star
            print "We have to find a new star\n";
            exit;
        }
    }

    print "SENDING PROBES again in 30 minutes\n\n";
    sleep(1800);

    $observatory->refresh;
    $space_port->refresh;
}


# Save probe data in database

sub _save_probe_data {
    my ($schema, $probed_star, $status) = @_;

    # See if we have previously probed this star
    my $db_star = $schema->resultset('Star')->find($probed_star->id);

    if ($db_star->status == 1) {
        # Then the probe was sent by this script. Override any status
        $status = 3;
    }

    if ($db_star->scan_date) {
        print "Previously scanned [".$db_star->name."]. Don't scan again\n";
        if ($db_star->status == 1) {
            $db_star->status($status);
            $db_star->update;
        }
    }
    else {
        print "Saving scanned data for [".$db_star->name."]\n";
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
        $db_star->status($status);
        # If status is '3' then the probe is currently registered by our observatory
        # If the status is '2' then there is no probe, it was probably an alliance member
        $db_star->empire_id($status == 3 ? $api->my_empire->id : 0);
        $db_star->update;
    }
}
1;
