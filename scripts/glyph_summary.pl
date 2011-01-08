#!/home/icydee/localperl/bin/perl

# Carry out a survey of all colonies, check in all the archaeology ministries
# and get a total of all glyphs held by the empire
#

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::Agent::ShipBuilder;

# Load configurations

my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

my $api = WWW::LacunaExpanse::API->new({
    uri         => $my_account->{uri},
    username    => $my_account->{username},
    password    => $my_account->{password},
});

my $colonies = $api->my_empire->colonies;
my $total_glyph_count;

for my $colony (sort {$a->name cmp $b->name} @$colonies) {
    print "Colony ".$colony->name." at ".$colony->x."/".$colony->y."\n";
    my ($archaeology) = @{$colony->building_type('Archaeology Ministry')};

    if ($archaeology ) {
        my $colony_glyph_count = $archaeology->get_glyph_summary;

        for my $glyph_type (keys %$colony_glyph_count) {
            if (! $total_glyph_count->{$glyph_type} ) {
                # initialise it
                $total_glyph_count->{$glyph_type} = 0;
            }
            $total_glyph_count->{$glyph_type} += $colony_glyph_count->{$glyph_type};
        }

        for my $glyph_type (sort keys %$colony_glyph_count) {
            print "  ".$colony_glyph_count->{$glyph_type}."\t".$glyph_type."\n";
        }
    }
    else {
        print "  Has no archaeology ministry\n";
    }
}

print "\nTOTAL GLYPHS\n";
my $grand_total = 0;
for my $glyph_type (sort keys %$total_glyph_count) {
    print "  ".$total_glyph_count->{$glyph_type}."\t".$glyph_type."\n";
    $grand_total += $total_glyph_count->{$glyph_type};
}
print "    TOTAL\t$grand_total\n";

1;
