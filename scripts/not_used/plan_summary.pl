#!/home/icydee/localperl/bin/perl

# Carry out a survey of all colonies, check in all planetary command centres
# and get a total of all plans held by the empire
#

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

my $api = WWW::LacunaExpanse::API->new({
    uri         => $my_account->{uri},
    username    => $my_account->{username},
    password    => $my_account->{password},
    debug_hits  => $my_account->{debug_hits},
});

my $colonies = $api->my_empire->colonies;

my $plans;

COLONY:
for my $colony (sort {$a->name cmp $b->name} @$colonies) {
    print "Colony ".$colony->name." at ".$colony->x."/".$colony->y."\n";
    my $pcc = $colony->planetary_command_center;

    if ( ! $pcc ) {
        print "ERROR: For some reason there is no Planetary Command Center\n";
        next COLONY;
    }

    print "Build stats are ".$pcc->planet_stats."\n";
}


1;
