#!/home/icydee/localperl/bin/perl

# Script to send out probes. Used in conjunction with the send_excavators.pl script
#
# Send probes out to random stars within a range of distances from a central
# location (usually towards the centre of an empire).
#
# Currently either you fill up the ship building queue manually or run a
# different script to do it for you (still under development) to ensure that
# there are enough probed stars ready to accept the excavators
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

my $dsn = "dbi:SQLite:dbname=$Bin/".$my_account->{db_file};

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $my_account->{uri},
    username    => $my_account->{username},
    password    => $my_account->{password},
});

my $my_empire   = $api->my_empire;
my @colonies    = @{$my_empire->colonies};
my ($colony)    = grep {$_->name eq $excavate_config->{probe_colony_name}} @colonies;

print "Sending probes from  '".$colony->name."' ".$colony->x."/".$colony->y."\n";

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

# This script is intended to be run continuously. To stop it hit ctrl-c
#
RESCAN:
while (1) {

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
    my $sleep = $excavate_config->{send_probes_sleep};
    my $formatted_time = WWW::LacunaExpanse::API::DateTime->format_seconds($sleep);
    print "SENDING PROBES again in $formatted_time\n\n";
    sleep($sleep);

    $observatory->refresh;
    $space_port->refresh;
}


# Get a new candidate star to probe
#
# Currently we do not try to avoid stars with bodies excavated in
# the last 30 days, but if you send out far enough the chances are
# pretty slim. (It is a big universe out there!)
#
sub _next_star_to_probe {
    my ($schema, $space_port, $observatory) = @_;

    my ($star, $probe);

    # Locate a star at a random distance

    my $distance = int(rand($excavate_config->{max_distance} - $excavate_config->{min_distance})) + $excavate_config->{min_distance};
    print "Probing a distance of $distance\n";

    # Only send probes to stars previously unvisited or where the probe has been deleted
    # you 'could' make this only stars that have never been visited without a problem
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

1;
