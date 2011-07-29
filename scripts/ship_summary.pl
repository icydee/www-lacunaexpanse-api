#!/usr/bin/perl

# Print a summary of all ships in your empire in CSV format

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

my $ship_types;                         # Hash of all ship types we own

my $colony_has;                         # Hash of colony/ship-types

COLONY:
for my $colony (sort {$a->name cmp $b->name} @$colonies) {
    print "Colony: ".$colony->name." at ".$colony->x."/".$colony->y."\n";

    my $space_port = $colony->space_port;
    next COLONY if ! $space_port;

    $colony_has->{$colony->name}{space_port} = $space_port;

    for my $ship ($space_port->all_ships) {
        my $ship_type = $ship->type;
        $ship_types->{$ship_type} = 1;

        $colony_has->{$colony->name}{$ship_type} =
            defined $colony_has->{$colony->name}{$ship_type}
            ? $colony_has->{$colony->name}{$ship_type} + 1
            : 1
            ;
    }
}

#print Dumper(\$colony_has);

my $title = join (',', map {uc($_)} sort keys %$ship_types);
print "COLONY,DOCKS,AVAILABLE,$title\n";


for my $colony_name (sort keys %$colony_has) {
    my ($colony) = grep {$_->name eq $colony_name} @$colonies;
    my $space_port = $colony_has->{$colony_name}{space_port};

    my $str = '';
    $str .= join(',', $colony->name, $space_port->max_ships, $space_port->docks_available);
    $str .= ',';
SHIP_TYPE:
    for my $ship_type (sort keys %{$ship_types}) {
        my $qty = $colony_has->{$colony_name}{$ship_type};
        $qty = 0 if ! $qty;
        $str .= "$qty,";
    }
    chop($str);
    print "$str\n";
}

exit;

1;
