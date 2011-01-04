#!/home/icydee/localperl/bin/perl

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
my $total_glyph_count;

for my $colony (sort {$a->name cmp $b->name} @$colonies) {
    print $colony->name." at ".$colony->x."/".$colony->y."\n";
    my @archaeologies = @{$colony->building_type('Archaeology Ministry')};

    my $colony_glyph_count;
    for my $archaeology (@archaeologies) {
#        print "Archaeology at ".$archaeology->x."/".$archaeology->y."\n";
        my @glyphs = @{$archaeology->glyphs};
        for my $glyph (@glyphs) {
            my $glyph_type = $glyph->type;
            $total_glyph_count->{$glyph_type}  = $total_glyph_count->{$glyph_type}  ? $total_glyph_count->{$glyph_type}  + 1 : 1;
            $colony_glyph_count->{$glyph_type} = $colony_glyph_count->{$glyph_type} ? $colony_glyph_count->{$glyph_type} + 1 : 1;
        }
        for my $glyph_type (sort keys %$colony_glyph_count) {
            print "  ".$colony_glyph_count->{$glyph_type}."\t".$glyph_type."\n";
        }
    }
}

print "TOTAL GLYPHS\n";
my $grand_total = 0;
for my $glyph_type (sort keys %$total_glyph_count) {
    print "  ".$total_glyph_count->{$glyph_type}."\t".$glyph_type."\n";
    $grand_total += $total_glyph_count->{$glyph_type};
}
print "    TOTAL\t$grand_total\n";



exit;

1;
