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
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

my $my_account      = YAML::Any::LoadFile("$Bin/myaccount.yml");
my $excavate_config = YAML::Any::LoadFile("$Bin/excavate.yml");

my $dsn = "dbi:SQLite:dbname=$Bin/".$excavate_config->{db_file};

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $my_account->{uri},
    username    => $my_account->{username},
    password    => $my_account->{password},
});

my $my_empire   = $api->my_empire;
my @colonies    = @{$my_empire->colonies};
my ($colony)    = grep {$_->name eq $excavate_config->{probe_colony_name}} @colonies;

print "Sending probes from my colony [".$colony->name."] ".$colony->x."/".$colony->y."\n";

my $centre_star = $api->find({ star => $excavate_config->{centre_star_name} }) || die "Cannot find star (".$excavate_config->{centre_star_name},")";

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
#print "Observatory has probed: [".$observatory->count_probed_stars."] stars.\n";
#
#while (my $probed_star = $observatory->next_probed_star) {
#    _save_probe_data($schema, $probed_star, 3);
#}

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
    ### Send probes out to new stars                                                 ###
    ####################################################################################

    my @probes_docked       = grep {$_->task eq 'Docked'}       $space_port->all_ships('probe');
    my @probes_travelling   = grep {$_->task eq 'Travelling'}   $space_port->all_ships('probe');

    # Max number of probes we can send is the observatory max_probes minus observatory probed_stars
    # minus the number of travelling probes.
    #
    my $observatory_probes_free = $observatory->max_probes - $observatory->count_probed_stars - scalar @probes_travelling;
    print "There are $observatory_probes_free slots available\n";
    print "There are ".scalar(@probes_docked)." docked probes\n";
    my $max_probes_to_send = min(scalar(@probes_docked), $observatory_probes_free);
PROBE:
    while ($max_probes_to_send) {

        my ($probeable_star, $probe) = _next_star_to_probe($schema, $space_port, $observatory);
        if ( ! $probeable_star ) {
            print "Something seriously wrong. Can't find a star to probe\n";
            last PROBE;
        }

        print "Sending probe ID ".$probe->id." to star ".$probeable_star->name;
        my $arrival_time = $space_port->send_ship($probe->id, {star_id => $probeable_star->id});

        # mark the star as 'pending' the arrival of the probe
        $probeable_star->status(1);
        $probeable_star->update;
        print " and will arrive at $arrival_time\n";

        $max_probes_to_send--;
    }

    print "SENDING PROBES again in 60 minutes\n\n";
    sleep(3600);

    $observatory->refresh;
    $space_port->refresh;
}


# Get a new candidate star to probe
#
# Star must not have been excavated in the last 32 days
#
sub _next_star_to_probe {
    my ($schema, $space_port, $observatory) = @_;

    my ($star, $probe);

    # Locate a star at a random distance

    my $distance = int(rand($excavate_config->{max_distance} - $excavate_config->{min_distance})) + $excavate_config->{min_distance};
    print "Probing a distance of $distance\n";

    my $distance_rs = $schema->resultset('Distance')->search_rs({
        from_id             => $centre_star->id,
        'to_star.status'    => [5, undef ],
        distance            => {'>', $distance},
    }
    ,{
        join        => 'to_star',
        order_by    => 'distance',
    });

DISTANCE:
    while (my $distance = $distance_rs->next) {
        $star = $distance->to_star;

        print "Getting available ships for ".$star->name."\n";
        my $available_ships     = $space_port->get_available_ships_for({ star_id => $star->id });
        my @available_probes    = grep {$_->type eq 'probe'} @$available_ships;

        $probe = $available_probes[0];
        last DISTANCE if $probe;
    }
    print "  ".$probe->id." probe found\n";
    return ($star,$probe);
}

## Save probe data in database
#
#sub _save_probe_data {
#    my ($schema, $probed_star, $status) = @_;
#
#    # See if we have previously probed this star
#    my $db_star = $schema->resultset('Star')->find($probed_star->id);
#
#    if ($db_star->status == 1) {
#        # Then the probe was sent by this script. Override any status
#        $status = 3;
#    }
#
#    if ($db_star->scan_date) {
#        print "Previously scanned [".$db_star->name."]. Don't scan again\n";
#        if ($db_star->status == 1) {
#            $db_star->status($status);
#            $db_star->update;
#        }
#    }
#    else {
#        print "Saving scanned data for [".$db_star->name."]\n";
#        for my $body (@{$probed_star->bodies}) {
#            my $db_body = $schema->resultset('Body')->find($body->id);
#            if ( $db_body ) {
#                # We already have the body data, just update the empire data
#                $db_body->empire_id($body->empire ? $body->empire->id : undef);
#                $db_body->update;
#            }
#            else {
#                # We need to create it
#                my $db_body = $schema->resultset('Body')->create({
#                    id          => $body->id,
#                    name        => $body->name,
#                    x           => $body->x,
#                    y           => $body->y,
#                    image       => $body->image,
#                    size        => $body->size,
#                    type        => $body->type,
#                    star_id     => $probed_star->id,
#                    empire_id   => $body->empire ? $body->empire->id : undef,
#                    water       => $body->water,
#                });
#                # Check the ores for this body
#                my $body_ore = $body->ore;
#                for my $ore_name (WWW::LacunaExpanse::API::Ores->ore_names) {
#                    # we only store ore data if the quantity is greater than 1
#                    if ($body_ore->$ore_name > 1) {
#                        my $db_ore = $schema->resultset('LinkBodyOre')->create({
#                            ore_id      => WWW::LacunaExpanse::API::Ores->ore_index($ore_name),
#                            body_id     => $db_body->id,
#                            quantity    => $body_ore->$ore_name,
#                        });
#                    }
#                }
#
#            }
#        }
#        $db_star->scan_date(DateTime->now);
#        $db_star->status($status);
#        # If status is '3' then the probe is currently registered by our observatory
#        # If the status is '2' then there is no probe, it was probably an alliance member
#        $db_star->empire_id($status == 3 ? $api->my_empire->id : 0);
#        $db_star->update;
#    }
#}
1;
