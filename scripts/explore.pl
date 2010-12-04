#!/home/icydee/localperl/bin/perl

# Script that will manage a fleet of probes, sending them out
# further and further from the home planet and gathering a
# database of nearby stars and their resourses.
#

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;

#### Configuration ####
my $uri             = 'https://us1.lacunaexpanse.com';
my $username        = 'icydee-2';
my $password        = 'Ammal56aam';
my $dsn             = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

my $max_probes          = 2;                # Max probes to create/destroy
my $probe_names         = 'Explore Probe';  # Name to give probes used by this script
my $centre_star_name    = 'Wee Eafre';      # Name of star to act as centre of search pattern
my $search_from_colony  = 'icydee-2-1';     # Name of colony to send probes from

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

my $colony = $api->find({ my_colony => 'icydee-2-1' });

print "Sending probes from my colony [".$colony->name."] ".$colony->x."/".$colony->y."\n";

my $shipyard = $colony->shipyard;
print "Shipyard has [".$shipyard->docks_available."] docks available\n";

#my $probe_build_status = $shipyard->ship_build_status('probe');
#if ( ! $probe_build_status->can ) {
#    print "Cannot build probe because of code [".$probe_build_status->reason_code."] reason [".$probe_build_status->reason_text."]\n";
#    exit;
#}
#print "About to build a probe\n";
#$shipyard->build_ship('probe');
#
#
#exit;
##my @ships = $shipyard->buildable;
#
#if ($shipyard->docks_available > 0) {
#    $shipyard->build_ship('Probe');
#}
#
#exit;

my $centre_star = $api->find({ star => $centre_star_name }) || die "Cannot find star ($centre_star_name)";

my $observatory = $colony->observatory;
my $space_port  = $colony->space_port;

# Ensure we have all the distances between the centre star and all the other stars.
my $distance_count  = $schema->resultset('Distance')->search({from_id => $centre_star->id})->count;
my $star_count      = $schema->resultset('Star')->search()->count;
print "Distance_count=$distance_count star_count=$star_count\n";

goto GOTO;
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

#
# Check all the probes currently registered by the observatory
#
print "Observatory has probed: [".$observatory->count_probed_stars."] stars.\n";
while (my $probed_star = $observatory->next_probed_star) {

    _save_probe_data($schema, $probed_star);

    print "  Star name: [".$probed_star->name."]\n";
    for my $body (@{$probed_star->bodies}) {
        print "    Body: [".$body->name."]\n";
        print "    water: [".$body->water."]\n";
    }
}

# Now create some more probes
GOTO:
# Now select the next star to probe

# summary of space port
print "The space port can hold a maximum of ".$space_port->max_ships." ships\n";

my $docked_probes = $space_port->docked_ships('probe');
print "there are [$docked_probes] docked probes\n";

my $docked_cargo = $space_port->docked_ships('cargo_ship');
print "there are [$docked_cargo] docked cargo ships\n";

if ($docked_probes) {
    # If there are docked probes, see if we can deploy them.

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

        if (@{$star->bodies}) {
            print "Star (".$star->name.") has already been probed\n";
            print "    (".scalar(@{$star->bodies}).")\n";
            # Save the data in the database

            _save_probe_data($schema, $star);

        }
        else {
            print "Star (".$star->name.") has NOT been probed\n";
        }
    }
}

exit;


my $next_distance_rs = $schema->resultset('Distance')->search_rs({
    from_id             => $centre_star->id,
    'to_star.status'    => undef,
    }
    ,{
        join        => 'to_star',
        order_by    => 'distance',
    });

my $star = $next_distance_rs->next->to_star;
print "Star = [".$star->name."] (".$star->x."/".$star->y.")\n";
#print Dumper(\$star);
exit;

print "Nearest star is [".$star->name."]\n";
exit;


# Save probe data in database

sub _save_probe_data {
    my ($schema, $probed_star) = @_;

    # See if we have previously probed this star
    my $db_star = $schema->resultset('Star')->find($probed_star->id);
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
        $db_star->empire_id($api->my_empire->id);
        $db_star->update;
    }
}
1;
