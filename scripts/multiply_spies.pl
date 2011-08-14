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
    my $intel_ministry          = $train_on_colony->intelligence;

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

    # This script only works if the intel ministry is initially empty
    my $spies_current = $intel_ministry->current;
    $log->info("There are currently $spies_current spies in the intelligence ministry");

    my $spies;

    # We cycle continuously until stopped with a Ctrl-C
    while (1) {

        # Build the maximum allotment of spies on the training colony
        my $spies_to_train = $intel_ministry->maximum - $intel_ministry->current;
        $log->info("Training $spies_to_train spies on colony ".$train_on_colony->name);
        while ($spies_to_train) {
            # train spies
            my $spy_batch = $spies_to_train <= 5 ? $spies_to_train : 5;
            $spies_to_train -= $spy_batch;
            my $spies_trained = $intel_ministry->train_spy($spy_batch);
            if ($spies_trained != $spy_batch) {
                $log->error("Could only train $spies_trained spies out of a total of $spy_batch");
            }
        }

        # Wait the training period
        $log->info("Sleeping for ".$config->{training_delay}." minutes while training takes place");
        sleep $config->{training_delay} * 60;

        # Get a list of all our trained spies, put them up for sale
        my $all_spies = $intel_ministry->all_spies;
        for my $spy (@$all_spies) {
            $log->debug("Putting spy $spy [".Dumper($spy)."] up for sale");
            $spies->{$spy->id} = $spy;
        }
        SPY:
        for my $spy_id (keys %$spies) {
            # Put the spy up for sale on our training colony
            my $spy = $spies->{$spy_id};
            next SPY unless $spy->is_available;

            $log->debug("Trading spy $spy_id");
            my $trade_id = $merc_guild_train->add_to_market($spies->{$spy_id}, 10);

            # Purchase the spy on the transfer colony
            $merc_guild_transfer->accept_from_market($trade_id);
        }

        # Wait the transfer period
        $log->info("Sleeping for ".$config->{transfer_delay}." minutes while the transfer takes place");
        sleep $config->{transfer_delay} * 60;
    }
}

1;
