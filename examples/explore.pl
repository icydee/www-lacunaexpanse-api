#!/home/icydee/localperl/bin/perl
use strict;
use warnings;

# Script that will manage a fleet of probes, sending them out
# further and further from the home planet and gathering a
# database of nearby stars and their resourses.
#

use lib "lib";
use Data::Dumper;

use WWW::LacunaExpanse::API;


#### Configuration ####
my $uri         = 'https://us1.lacunaexpanse.com';
my $username    = 'icydee-2';
my $password    = 'Ammal56aam';

my $database    = 'database/lacuna.db';
my $max_probes  = 2;                        # Max probes to create/destroy
my $probe_names = 'Explore Probe';          # Name to give probes used by this script

#### End of Configuration ####

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

#my $stars = $api->find({star => 'Oss Gairvi'});        # beermat's home star
#for my $star (@$stars) {
#    print $star;
#}
#exit;

my $home = $api->my_empire->home_planet;

print "Sending probes from my home planet [".$home->name."] ".$home->x."/".$home->y."\n";

my $space_port = $home->space_port;

print "Spaceport [$space_port]\n";
$space_port->test;

exit;

#print $home;
for my $building (@{$home->buildings()}) {
    print "Building [".$building->name."] [$building]\n";
}

# Check if the distance table has been set up yet



