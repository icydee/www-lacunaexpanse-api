#!/usr/bin/perl

# count the number of Halls of Verbansk.
#

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
use WWW::LacunaExpanse::Agent::ShipBuilder;
use WWW::LacunaExpanse::API::Ores;

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../plan_summary.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
    });

    my $colonies = $api->my_empire->colonies;
    my $hall_count = 0;

    my ($colony) = grep {$_->name eq 'wae5'} @$colonies;

    my $trade_ministry = $colony->trade_ministry;
    if ($trade_ministry) {
PLAN:
        for my $plan (@{$trade_ministry->plans}) {
            next PLAN unless $plan->name eq 'Halls of Vrbansk';
            $hall_count++;
        }
    }
    else {
        $log->warn("  Has no trade ministry");
    }
    $log->info("There are $hall_count halls on vom5");
}

1;
