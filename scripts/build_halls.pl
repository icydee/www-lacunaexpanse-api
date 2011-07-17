#!/usr/bin/perl

# Build as many halls as possible from plans on a colony

use Modern::Perl;
use FindBin qw($Bin);
use Log::Log4perl;
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::DB;
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../build_halls.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");
    my $config          = YAML::Any::LoadFile("$Bin/../build_halls.yml");

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
    });

    my $empire      = $api->my_empire;
    my $colonies    = $empire->colonies;

    my $build_on = $config->{build_on};

COLONY:
    for my $colony (sort {$a->name cmp $b->name} @$colonies) {
        # Only build halls on colonies specified in the config file
        next COLONY unless grep {$_ eq $colony->name} keys %$build_on;

        $log->info("Building ".$build_on->{$colony->name}." halls on colony ".$colony->name);

        if ($build_on->{$colony->name} > 99) {
            $log->error("You are only allowed to build 99 Halls on a single colony");
            next COLONY;
        }

        my $free_building_spaces = $colony->get_free_building_spaces;

#        $log->debug(join (' - ', map {$_->name} @{$colony->buildings}));

        my $built_halls = grep {$_->name eq 'Halls of Vrbansk'} @{$colony->buildings};
        $log->debug("There are already $built_halls halls built");

        SPACE:
        for my $space (@$free_building_spaces) {
            last SPACE if $built_halls >= $build_on->{$colony->name};

            $log->info("Build on space x ".$space->{x}." y ".$space->{y});
            my $success = $colony->build_a_building('HallsOfVrbansk', $space->{x}, $space->{y});
            last SPACE if not $success;
            $built_halls++;
        }
    }
}

1;
