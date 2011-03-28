#!/home/icydee/localperl/bin/perl

# Take out the waste from a colony.

use Modern::Perl;
use FindBin qw($Bin);
use Log::Log4perl;
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../take_out_waste.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
    });

    my $colonies = $api->my_empire->colonies;

COLONY:
    for my $colony (sort {$a->name cmp $b->name} @$colonies) {
        $log->info("Colony ".$colony->name." at ".$colony->x."/".$colony->y);
        next COLONY unless $colony->name eq 'icydee hw3';

        # find the junk henge (if any)
        my $junk_henge = $colony->junk_henge_sculpture;
        if ($junk_henge) {
            my $x = $junk_henge->x;
            my $y = $junk_henge->y;
            $log->debug("Waste henge is at $x/$y");

            # Now we can keep demolishing it and building it until the waste is gone
            while (1) {
                $junk_henge->demolish;
                $colony->
            }
        }
    }
}

1;
