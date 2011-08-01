#!/usr/bin/perl

# Script to run continuously in order to multiply the number of spies we have
# by training them on one colony which has a level 30 mercenaries guild and
# selling them (cost zero E to post on a level 30 mercenaries guild) to 
# one's self on another colony
# Subsequently those spies can be 'upgraded' in bulk by upgrading the 
# security ministry and espionage ministry.
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

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../multiply_spies.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");
    my $config          = YAML::Any::LoadFile("$Bin/../multiply_spies.yml");

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
    });

    my $empire      = $api->my_empire;
    my $colonies    = $empire->colonies;

    my ($train_on_colony, $transfer_to_colony);

COLONY:
    for my $colony (sort {$a->name cmp $b->name} @$colonies) {
        if ($colony->name eq $config->{train_on}) {
            $train_on_colony = $colony;
        }
        if ($colony->name eq $config->{transfer_to}) {
            $transfer_to_colony = $colony;
        }
    }
    if (not defined $train_on_colony) {
        $log->fatal("train_on colony ".$config->{train_on}." cannot be found");
        exit;
    }
    if (not defined $transfer_to_colony) {
        $log->fatal("transfer_to colony ".$config->{transfer_to}." cannot be found");
        exit;
    }
    
    # Both colonies should have a mercenaries guild
    my $merc_guild_train        = $train_on_colony->mercenaries_guild;
    my $merc_guild_transfer     = $transfer_to_colony->mercenaries_guild;

    # The training colony should have an intelligence ministry
    my $intel_ministry          = $train_on_colony->intelligence_ministry;

    if (not defined $merc_guild_train) {
        $log->fatal("No mercenaries guild on colony ".$train_on_colony->name);
        exit;
    }
    if (not defined $merc_guild_transfer) {
        $log->fatal("No mercenaries guild on colony ".$transfer_to_colony->name);
        exit;
    }
    if (not defined $intel_ministry) {
        $log->fatal("No Intelligence Ministry on colony ".$train_on_colony->name);
        exit;
    }

    # We cycle continuously until stopped with a Ctrl-C
    while (1) {

        # Build the maximum allotment of spies on the training colony

        # Wait the training period
        $log->info("Sleeping for ".$config->{training_delay}." minutes while training takes place");
        sleep $config->{training_delay} * 60;

        # Purchase the trained spies from the transfer colony

        # Wait the transfer period
        $log->info("Sleeping for ".$config->{transfer_delay}." minutes while the transfer takes place");
        sleep $config->{transfer_delay} * 60;

    }
}

1;
