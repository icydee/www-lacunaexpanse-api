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
use Getopt::Long;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::Agent::ShipBuilder;
use WWW::LacunaExpanse::API::Ores;

# Load configurations

MAIN: {

    my $log4perl_conf   = "$Bin/../configs/hall_count.log4perl.conf";
    my $account_yml     = "$Bin/../configs/myaccount.yml";
    my $config_yml      = "$Bin/../configs/hall_count.yml";

    my $result = GetOptions(
        'log4perl=s'    => \$log4perl_conf,
        'account=s'     => \$account_yml,
        'config=s'      => \$config_yml,
    );

    Log::Log4perl::init($log4perl_conf);

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile($account_yml);
    my $config          = YAML::Any::LoadFile($config_yml);
 
    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
    });

    my $colonies = $api->my_empire->colonies;
    
COLONY:
    for my $colony_name ( @{$config->{colonies}}) {
        $log->info("Checking colony $colony_name");
        my $hall_count = 0;

        my ($colony) = grep {$_->name eq $colony_name} @$colonies;

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
        $log->info("There are $hall_count hall plans on $colony_name");
    }
}

1;
