#!/home/icydee/localperl/bin/perl

# Carry out a survey of all colonies, get a report on the number of each type
# of plan held there.
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
    my $all_plans;

    for my $colony (sort {$a->name cmp $b->name} @$colonies) {
        $log->info("Colony ".$colony->name." at ".$colony->x."/".$colony->y);

        my $colony_plans;
        my $trade_ministry = $colony->trade_ministry;
        if ($trade_ministry) {
            for my $plan (@{$trade_ministry->plans}) {
                # id,name,level,extra_build_level
                if (! defined $colony_plans->{$plan->name}{$plan->level}{$plan->extra_build_level}) {
                    $colony_plans->{$plan->name}{$plan->level}{$plan->extra_build_level} = 0;
                }
                $colony_plans->{$plan->name}{$plan->level}{$plan->extra_build_level}++;
                if (! defined $all_plans->{$plan->name}{$plan->level}{$plan->extra_build_level}) {
                    $all_plans->{$plan->name}{$plan->level}{$plan->extra_build_level} = 0;
                }
                $all_plans->{$plan->name}{$plan->level}{$plan->extra_build_level}++;
            }

            for my $plan_name (sort keys %$colony_plans) {
                for my $level (sort keys %{$colony_plans->{$plan_name}}) {
                    for my $extra (sort keys %{$colony_plans->{$plan_name}{$level}}) {
                        $log->info("PLAN: $plan_name, LEVEL: $level+$extra, QTY: ".$colony_plans->{$plan_name}{$level}{$extra});
                    }
                }
            }
        }
        else {
            $log->warn("  Has no trade ministry");
        }
    }
    $log->info("EMPIRE WIDE STATS");
    for my $plan_name (sort keys %$all_plans) {
        for my $level (sort keys %{$all_plans->{$plan_name}}) {
            for my $extra (sort keys %{$all_plans->{$plan_name}{$level}}) {
                $log->info("PLAN: $plan_name, LEVEL: $level+$extra, QTY: ".$all_plans->{$plan_name}{$level}{$extra});
            }
        }
    }
}

1;
