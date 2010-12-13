#!/home/icydee/localperl/bin/perl

# Script to search a location is space for stars, sending out probes to
# unvisited stars gradually expanding from a central star.
# The visited stars and the planets data are gathered and stored in an SqLite
# database.
# As observatory probe locations are filled, older probes are destroyed.
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
my $username                = 'your_username';
my $password                = 'your_password';

my $uri                     = 'https://us1.lacunaexpanse.com';
my $dsn                     = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

my $spaces_in_spaceport     = 2;                # Leave at least this many spaces in the spaceport
my $spaces_in_observatory   = 2;                # Leave at least this many spaces in the observatory
my $probes_in_spaceport     = 2;                # Leave this many probes in the spaceport unused
my $probes_max_build_queue  = 1;                # Max number of probes to have in the build queue
my $centre_star_name        = 'Lio Easphai';    # Name of star to act as centre of search pattern
my $search_from_colony      = 'your_colony';    # Name of colony to send probes from
#my @search_quadrants        = qw[TR BR BL TL];  # Quadrant to search Top Right, Bottom Right, etc.

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

my $colony = $api->find({ my_colony => 'icydee-2-1' });

print "Sending probes from my colony [".$colony->name."] ".$colony->x."/".$colony->y."\n";

my $centre_star = $api->find({ star => $centre_star_name }) || die "Cannot find star ($centre_star_name)";

my $observatory = $colony->observatory;
my $space_port  = $colony->space_port;
my $shipyard    = $colony->shipyard;

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
    _save_probe_data($schema, $probed_star, 5);
}

# Hash to calculate SQL for quadrant calculation.
# Sort all quadrants first to get BL,BR,TL,TR
# NOTE: This is a work-in-progress!
#
#my $quadrants = {
#    BL          => {x => {'<',  $centre_star->x}, y => {'<',  $centre_star->y}},
#    BR          => {x >= $centre_star->x, y <  $centre_star->y},
#    TL          => {x <  $centre_star->x, y <  $centre_star->y},
#    TR          => {x <  $centre_star->x, y >= $centre_star->y},
#    BL_BR       => {                      y <  $centre_star->y},
#    BL_TL       => {x <  $centre_star->x                      },
#    BL_TR       => {},
#    BR_TL       => {},
#    BR_TR       => {x >= $centre_star->x                      },
#    TL_TR       => {                      y >= $centre_star->y},
#
#    BL_BR_TL    => { -or => [x <  $centre_star->x, y <  $centre_star->y]},
#    BL_BR_TR    => { -or => [x >= $centre_star->x, y <  $centre_star->y]},
#    BL_TL_TR    => { -or => [x <  $centre_star->x, y >= $centre_star->y]},
#    BR_TL_TR    => { -or => [x >= $centre_star->x, y >= $centre_star->y]},
#
#    BL_BR_TL_TR => {},
#}


# This script is intended to be run continuously. To stop it hit ctrl-c
#
RESCAN:
while (1) {
    ####################################################################
    ### So long as the observatory can support it, create new probes ###
    ####################################################################

    # The number of probes we can have is the number of unused probes at the
    # observatory minus the number of probes in transit.
    # also taking into account the number of docks available at the shipyard
    # and the number of probes we want to use for ourself and the number of
    # docks we want to leave in the space-port for our own use ...
    #
    my $observatory_slots_free  = $observatory->max_probes - $observatory->count_probed_stars - $spaces_in_observatory;
    my $docks_available         = $shipyard->docks_available - $spaces_in_spaceport - $probes_in_spaceport;

    # Find out how many probes are in the space_port (being built, docked or travelling)
    $space_port->reset_ship;
    my @probes = $space_port->all_ships('probe');

    my $probes_docked       = grep {$_->task eq 'Docked'}       @probes;
    my $probes_building     = grep {$_->task eq 'Building'}     @probes;
    my $probes_travelling   = grep {$_->task eq 'Travelling'}   @probes;
    $observatory_slots_free -= $probes_travelling;
    $probes_docked          -= $probes_in_spaceport;

    print "There are $probes_docked probes that can be sent, $probes_building probes building and $probes_travelling probes travelling\n";

    print "We can build $observatory_slots_free based on the observatory\n";
    print "We can build $docks_available based on the spaceport\n";

    my $max_probes = min($observatory_slots_free, $docks_available, ($probes_max_build_queue - $probes_building));
    print "We can build $max_probes probes\n";

    # Query to determine the oldest probes to delete
    my $distance_rs = $schema->resultset('Distance')->search_rs({
        from_id             => $centre_star->id,
        'to_star.status'    => 3,
        }
        ,{
            join        => 'to_star',
            order_by    => 'scan_date',
        });

DELETE_PROBE:
    while ($observatory_slots_free <= 0) {

        my $distance = $distance_rs->next;
        if ( ! $distance ) {
            print "WARNING: Cannot find any old probes to delete\n";
            last DELETE_PROBE;
        }

        print "DELETE: Oldest probe at star, (".$distance->to_star->name.")\n";
        $observatory->abandon_probe($distance->to_id);
        $distance->to_star->status(4);          # we deleted the probe
        $distance->to_star->update;

        # We now have one more slot free (in theory)
        $observatory_slots_free++;
    }

    # Recalculate the maximum number of probes we can build.
    $max_probes = min($observatory_slots_free, $docks_available, ($probes_max_build_queue - $probes_building));
    print "We can now build $max_probes probes\n";

    # If we have probes then
    if ($max_probes > 0) {
        # See if the ship yard can accept another probe
        my $probe_build_status = $shipyard->ship_build_status('probe');
        if ($probe_build_status->can) {
            # restrict to the number of probes we can put on the build queue
            if ($probes_building >= $probes_max_build_queue) {
                print "Cannot put a probe on the build queue at this time\n";
            }
            else {
                print "Putting a new probe on the build queue\n";
                $shipyard->build_ship('probe');
            }
        }
        else {
            print "Cannot build a probe at this time\n";
        }
    }

    ########################################################################
    ### See if we can send a docked probe out to the next available star ###
    ########################################################################

    if ($probes_docked) {
        # If there are docked probes, see if we can deploy them.

        # SQL to order the stars to visit, closest first
        # quadrant calculations
        #   TR  x >= central_star.x
        #       y >= central_star.y
        #   BR  x >= central_star.x
        #       y <  central_star.y
        #   BL  x <  central_star.x
        #       y <  central_star.y
        #   TL  x <  central_star.x
        #       y >= central_star.y
        #
        my $distance_rs = $schema->resultset('Distance')->search_rs({
            from_id             => $centre_star->id,
            'to_star.status'    => undef,
            'to_star.scan_date' => undef,
            }
            ,{
                join        => 'to_star',
                order_by    => 'distance',
            });

STAR:
        while (my $distance = $distance_rs->next) {
            # Check if the star has been probed by an Alliance member
            my $star = WWW::LacunaExpanse::API::Star->new({
                id  => $distance->to_star->id,
            });
            my $db_star = $schema->resultset('Star')->find($distance->to_star->id);

            if (@{$star->bodies}) {
                print "Star (".$star->name.") has already been probed (probably by an alliance member)\n";
                print "    (".scalar(@{$star->bodies}).")\n";

                # Save the data in the database
                _save_probe_data($schema, $star, 2);

            }
            else {
                print "Star (".$star->name.") has NOT been probed. Try to send a probe now\n";

                my $available_ships = $space_port->get_available_ships_for({ star_id => $star->id });

                my @probes = grep {$_->type eq 'probe'} @$available_ships;
                if (scalar @probes > $probes_in_spaceport) {
                    my $probe = $probes[0];
                    if ($probe) {
                        print "Sending probe ID ".$probe->id."\n";
                        my $arrival_time = $space_port->send_ship($probe->id, {star_id => $star->id});
                        # Mark the star as 'pending' the arrival of the probe
                        $db_star->status(1);
                        $db_star->update;
                        print "Probe will arrive at $arrival_time\n";
                        # Push the probe arrival time on the job queue


                    }
                    else {
                        print "Warning: Cannot find a probe to send\n";
                        last STAR;
                    }
                }
                else {
                    print "Warning: Cannot find a probe to send\n";
                    last STAR;
                }
            }
        }
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
    print "Rescan again in 30 minutes\n";
    sleep(1800);

    $shipyard->refresh;
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
    }
    else {
        print "Saving scanned data for [".$db_star->name."]\n";
        for my $body (@{$probed_star->bodies}) {
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
        $db_star->scan_date(DateTime->now);
        $db_star->status($status);
        # If status is '3' then the probe is currently registered by our observatory
        # If the status is '2' then there is no probe, it was probably an alliance member
        $db_star->empire_id($status == 3 ? $api->my_empire->id : 0);
        $db_star->update;
    }
}
1;
