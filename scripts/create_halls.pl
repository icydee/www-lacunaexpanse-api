#!/home/icydee/localperl/bin/perl

# Convert all glyphs into halls

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
    Log::Log4perl::init("$Bin/../create_halls.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");
    my $config          = YAML::Any::LoadFile("$Bin/../create_halls.yml");

#    my $api = WWW::LacunaExpanse::API->new({
#        uri         => $my_account->{uri},
#        username    => $my_account->{username},
#        password    => $my_account->{password},
#    });
#
#    my $colonies = $api->my_empire->colonies;

    my $assemble_on = $config->{assemble_on};

print Dumper ($assemble_on);

my $hall_def = {
    a   => [qw(goethite halite gypsum trona)],
    b   => [qw(gold anthracite uraninite bauxite)],
    c   => [qw(kerogen methane sulfur zircon)],
    d   => [qw(monazite fluorite beryl magnetite)],
    e   => [qw(rutile chromite chalcopyrite galena)],
};

COLONY:
    for my $colony (sort {$a->name cmp $b->name} @$colonies) {
        # Only assemble glyphs on colonies which are defined in the config file
        next COLONY unless grep {$_ eq $colony->name} @$assemble_on;

        my $archaeology = $colony->archaeology;
        if ( ! $archaeology ) {
            $log->error("Colony ".$colony->name." does not have an archaeology ministry");
            next COLONY;
        }

        my $glyphs = $archaeology->get_glyphs;

        for my $hall (sort keys %$hall_def) {
            my @types;
            for my $i (0..3) {
                $types[$i] = [grep {$_->name eq $hall->[$i]} @$glyphs];
            }
            while ($types[0] && $types[1] && $types[2] && $types[3]) {
                my $g0 = shift @{$types[0]->[0]};
                my $g1 = shift @{$types[1]->[0]};
                my $g2 = shift @{$types[2]->[0]};
                my $g3 = shift @{$types[3]->[0]};

                print "Assemble ".
                    join(" ", map {$_->id."-".$_->name} $g0,$g1,$g2,$g3).
                    "\n";

#                $archaeology->assemble_glyphs([
#                    shift(@{$types[0]->[0]}),
#                    shift(@{$types[1]->[0]}),
#                    shift(@{$types[2]->[0]}),
#                    shift(@{$types[3]->[0]}),
#                ]);
            }
        }
    }
}

1;
