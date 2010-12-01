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
my $uri         = 'https://us1.lacunaexpanse.com';
my $username    = 'icydee-2';
my $password    = 'Ammal56aam';
my $dsn         = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

my $max_probes  = 2;                        # Max probes to create/destroy
my $probe_names = 'Explore Probe';          # Name to give probes used by this script
my $from_id     = 450213;                   # ID of star to act as centre of search pattern

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

my $home = $api->my_empire->home_planet;

print "Sending probes from my home planet [".$home->name."] ".$home->x."/".$home->y."\n";

my $observatory = $home->observatory;

my $ore_index = {
    anthracite      => 1,
    bauxite         => 2,
    beryl           => 3,
    chalcopyrite    => 4,
    chromite        => 5,
    fluorite        => 6,
    galena          => 7,
    goethite        => 8,
    gold            => 9,
    gypsum          => 10,
    halite          => 11,
    kerogen         => 12,
    magnetite       => 13,
    methane         => 14,
    monazite        => 15,
    rutile          => 16,
    sulfur          => 17,
    trona           => 18,
    uraninite       => 19,
    zircon          => 20,
};

# Ensure we have all the distances between the home planet and all the stars.
my $distance_count  = $schema->resultset('Distance')->search({from_id => $from_id})->count;
my $star_count      = $schema->resultset('Star')->search()->count;

if ($distance_count != $star_count) {
    # Re-initialise the distance table
    $schema->resultset('Distance')->search({from_id => $from_id})->delete;
    my $star_rs = $schema->resultset('Star')->search_rs({});

    while (my $star = $star_rs->next) {
        my $distance = int(sqrt(($star->x - $home->x)**2 + ($star->y - $home->y)**2));
        $schema->resultset('Distance')->create({
            from_id     => $from_id,
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
    # See if we have previously probed this star
    my $db_star = $schema->resultset('Star')->find($probed_star->id);
    if ($db_star->scan_date) {
        print "Previously scanned [".$db_star->name."]. Don's scan again\n";
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
            for my $ore_name (qw(anthracite bauxite beryl chalcopyrite chromite fluorite galena goethite
                gold gypsum halite kerogen magnetite methane monazite rutile sulfur trona uraninite zircon)) {

                if ($body_ore->$ore_name > 1) {
                    my $db_ore = $schema->resultset('LinkBodyOre')->create({
                        ore_id      => $ore_index->{$ore_name},
                        body_id     => $db_body->id,
                        quantity    => $body_ore->$ore_name,
                    });
                }
            }

        }
        $db_star->scan_date(DateTime->now);
        $db_star->update;
    }


    print "  Star name: [".$probed_star->name."]\n";
    for my $body (@{$probed_star->bodies}) {
        print "    Body: [".$body->name."]\n";
        print "    water: [".$body->water."]\n";
    }
}


