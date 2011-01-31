#!/home/icydee/localperl/bin/perl

# Carry out a survey of all colonies, check in all the archaeology ministries
# and get a total of all glyphs held by the empire
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
    Log::Log4perl::init("$Bin/../glyph_summary.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
    });

    my $colonies = $api->my_empire->colonies;
    my $total_glyph_count;
    for my $glyph_type (WWW::LacunaExpanse::API::Ores->ore_names) {
        $total_glyph_count->{$glyph_type} = 0;
    }

    for my $colony (sort {$a->name cmp $b->name} @$colonies) {
        $log->info("Colony ".$colony->name." at ".$colony->x."/".$colony->y);
        my ($archaeology) = @{$colony->building_type('Archaeology Ministry')};

        if ($archaeology ) {
            my $colony_glyph_count = $archaeology->get_glyph_summary;

            for my $glyph_type (keys %$colony_glyph_count) {
                $total_glyph_count->{$glyph_type} += $colony_glyph_count->{$glyph_type};
            }

            for my $glyph_type (sort keys %$colony_glyph_count) {
                $log->info(sprintf("% 3u", $colony_glyph_count->{$glyph_type})."\t".$glyph_type);
            }
        }
        else {
            $log->warn("  Has no archaeology ministry");
        }
    }

    $log->info('TOTAL GLYPHS');
    my $grand_total = 0;
    for my $glyph_type (sort {$total_glyph_count->{$a} <=> $total_glyph_count->{$b}} keys %$total_glyph_count) {
        my $num = sprintf("% 3u", $total_glyph_count->{$glyph_type});

        $log->info("$num\t".$glyph_type);
        $grand_total += $total_glyph_count->{$glyph_type};
    }
    $log->info(sprintf("% 3u TOTAL GLYPHS", $grand_total));

    # Show how many halls of Vrbansk can be built
    my $hall_def = {
        a   => [qw(goethite halite gypsum trona)],
        b   => [qw(gold anthracite uraninite bauxite)],
        c   => [qw(kerogen methane sulfur zircon)],
        d   => [qw(monazite fluorite beryl magnetite)],
        e   => [qw(rutile chromite chalcopyrite galena)],
    };

    my $total_halls = 0;
    for my $hall_type (keys %$hall_def) {
        # the number of halls is the minimum of the count of glyphs that make up that hall
        my $halls = min map {$total_glyph_count->{$_}} @{$hall_def->{$hall_type}};
        $total_halls += $halls;
        $log->info(sprintf("% 3u ", $halls).join(',', @{$hall_def->{$hall_type}}));
    }
    $log->info(sprintf("% 3u TOTAL HALLS",$total_halls));

}

1;
