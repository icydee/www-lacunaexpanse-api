#!/home/icydee/localperl/bin/perl

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

my $my_account      = YAML::Any::LoadFile("$Bin/myaccount.yml");
my $excavate_config = YAML::Any::LoadFile("$Bin/excavate.yml");

my $dsn = "dbi:SQLite:dbname=$Bin/".$excavate_config->{db_file};

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $my_account->{uri},
    username    => $my_account->{username},
    password    => $my_account->{password},
});

my $colonies = $api->my_empire->colonies;
my @ships;

COLONY:
for my $colony (sort {$a->name cmp $b->name} @$colonies) {
    print $colony->name." at ".$colony->x."/".$colony->y."\n";

    my $space_port = $colony->space_port;
    next COLONY if ! $space_port;

    for my $ship ($space_port->all_ships) {
        push @ships, {ship => $ship, colony => $colony};
    }
}

# create summary
print "COLONY,TYPE,NAME,TASK,SIZE,SPEED,STEALTH,COMBAT,MAX_OCCUPANTS,AVAILABLE,STARTED,ARRIVES,TRAVEL_TIME\n";
for my $ship (sort {$a->{ship}->type.'#'.$a->{ship}->task cmp $b->{ship}->type.'#'.$b->{ship}->task} @ships) {
    print '"'.join('","', $ship->{colony}->name,
        $ship->{ship}->type,
        $ship->{ship}->name,
        $ship->{ship}->task,
        $ship->{ship}->hold_size,
        $ship->{ship}->speed,
        $ship->{ship}->stealth,
        $ship->{ship}->combat,
        $ship->{ship}->max_occupants,
        $ship->{ship}->date_available,
        $ship->{ship}->date_started,
        $ship->{ship}->date_arrives,
    )."\"\n";
}


exit;

1;
