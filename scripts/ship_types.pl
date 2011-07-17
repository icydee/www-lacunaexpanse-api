#!/usr/bin/perl

# Get all ship types buildable

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::Agent::ShipBuilder;

# Load configurations

my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

my $api = WWW::LacunaExpanse::API->new({
    uri         => $my_account->{uri},
    username    => $my_account->{username},
    password    => $my_account->{password},
    debug_hits  => $my_account->{debug_hits},
});

my $colonies = $api->my_empire->colonies;

COLONY:
for my $colony (sort {$a->name cmp $b->name} @$colonies) {
    next COLONY unless $colony->name eq 'hw3';

    my $shipyard = $colony->shipyard;
    next COLONY if ! $shipyard;

    my $buildable = $shipyard->buildable;
    my @buildables = sort {$a->type cmp $b->type} @$buildable;
    for my $ship (@buildables) {
        print "Buildable: ".$ship->type."\n";
    }
}

1;
