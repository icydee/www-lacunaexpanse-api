#!/usr/bin/perl

# Manage Glyphs
#
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";
#use FindBin::libs;

use Log::Log4perl;
use Data::Dumper;
use DateTime;
use DateTime::Precise;
use List::Util qw(min max);
use YAML::Any;

use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../attack.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');
    $log->info('Program start');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");
    my $config    = YAML::Any::LoadFile("$Bin/../attack.yml");

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
        debug_hits  => $my_account->{debug_hits},
    });
    my $empire = $api->my_empire;

    TARGET:
    for my $target_hash (@{$config->{targets}}) {
        my ($colony) = @{$empire->find_colony($target_hash->{from})};
        $log->debug("Sending ships from ".$colony->name." to ".$target_hash->{to});

        # Find out what ships we need to send
        my $ships_needed;

        for my $ship_hash (@{$target_hash->{ships}}) {
            my $ship_type = $ship_hash->{type};
            if (! defined $ships_needed->{$ship_type}) {
                $ships_needed->{$ship_type} = 0;
            }
            $ships_needed->{$ship_type} += $ship_hash->{qty};
        }

        my $space_port = $colony->space_port;

        # Get all the docked ships of those types at the spaceport
        my @ship_types  = keys %$ships_needed;

        $log->debug("Looking for ship types ".join('-',@ship_types));

        my @all_ships   = @{$space_port->view_all_ships({task => 'Docked', type => \@ship_types})};

        # Do we have enough ships of each type to send?
        my $we_have_all_ships = 1;

        SHIP:
        for my $ship_type (@ship_types) {
            $log->debug("Trying to send ".$ships_needed->{$ship_type}." ships of type $ship_type");
            # Do we have that many ships?
            my $qty = grep {$_->type eq $ship_type} @all_ships;
            $log->debug("We have $qty ships of type $ship_type to send");
            if ($qty < $ships_needed->{$ship_type}) {
                $we_have_all_ships = 0;
                $log->error("We don't have enough $ship_type ships to send");
            }
        }

        if ($we_have_all_ships) {
            $log->info("We can try to send the ships");
            # pull the ships off the @all_ships array
            my $max_fleet_speed = $target_hash->{speed} || 9999999999;
            my @send_ships;

            SHIP_HASH:
            for my $ship_hash (@{$target_hash->{ships}}) {
                my $ship_type   = $ship_hash->{type};
                my $ship_qty    = $ship_hash->{qty};
                for my $ship (@all_ships) {
                    if ($ship->type eq $ship_type) {
                        $max_fleet_speed = $max_fleet_speed < $ship->speed ? $max_fleet_speed : $ship->speed;
                        # put the ship on send_ships and remove from all_ships
                        push @send_ships, $ship;
                        @all_ships = grep {$_->id != $ship->id} @all_ships;
                        $ship_qty--;
                        next SHIP_HASH if $ship_qty <= 0;
                    }
                }
            }
            $log->info("Max ship speed is $max_fleet_speed");
            # Batch the ships into fleets of 10 ships
            $log->debug("Sending ".scalar(@send_ships)." ships to ".Dumper($target_hash->{to}));
            while (@send_ships) {
                my @fleet = splice @send_ships, 0, 20;
                my $fleet_speed = 0;
                $fleet_speed = $space_port->send_fleet(\@fleet, $target_hash->{to}, $max_fleet_speed);
                $log->debug("Fleet speed is - $fleet_speed. Ships are ".join(' - ', map {$_->type} @fleet));
                if ($fleet_speed == 0) {
                    $log->error("Cannot send fleet to target");
                    last TARGET;
                }
            }
        }
        else {
            $log->warn("We don't have enough ships to send!");
        }
    }
}
