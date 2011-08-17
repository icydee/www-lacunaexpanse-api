#!/usr/bin/perl

# Convert all glyphs into halls at specified colonies

use Modern::Perl;
use FindBin qw($Bin);
use Log::Log4perl;
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;
use Getopt::Long;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::DB;
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

MAIN: {
    my $log4perl_conf   = "$Bin/../create_halls.log4perl.conf";
    my $account_yml     = "$Bin/../myaccount.yml";
    my $config_yml      = "$Bin/../create_halls.yml";
    my $mysql_yml       = "$Bin/../mysql.yml";

    my $result = GetOptions(
        'log4perl=s'    => \$log4perl_conf,
        'account=s'     => \$account_yml,
        'config=s'      => \$config_yml,
        'mysql=s'       => \$mysql_yml,
    );

    Log::Log4perl::init($log4perl_conf);

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile($account_yml);
    my $config          = YAML::Any::LoadFile($config_yml);
    my $mysql_config    = YAML::Any::LoadFile($mysql_yml);

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
    });

    my $schema = WWW::LacunaExpanse::DB->connect(
        $mysql_config->{dsn},
        $mysql_config->{username},
        $mysql_config->{password},
        {AutoCommit => 1, PrintError => 1},
    );

    my $empire      = $api->my_empire;
    my $colonies    = $empire->colonies;

    my $assemble_on = $config->{assemble_on};

#print Dumper ($assemble_on);

my $hall_def = {
    a   => [qw(goethite halite gypsum trona)],
    b   => [qw(gold anthracite uraninite bauxite)],
    c   => [qw(kerogen methane sulfur zircon)],
    d   => [qw(monazite fluorite beryl magnetite)],
    e   => [qw(rutile chromite chalcopyrite galena)],
};
my $now = WWW::LacunaExpanse::API::DateTime->now;

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

        # Put all glyphs owned into the database
        for my $glyph (@$glyphs) {
            my $db_glyph = $schema->resultset('Glyph')->find({
                server_id   => 1,
                empire_id   => $empire->id,
                glyph_id    => $glyph->id
            });
            if ( ! $db_glyph) {
                # We have not previously inserted it, so save it now
                $db_glyph = $schema->resultset('Glyph')->create({
                    server_id   => 1,
                    empire_id   => $empire->id,
                    glyph_id    => $glyph->id,
                    glyph_type  => $glyph->type,
                    found_on    => $now,
                });
            }
        }

        for my $hall (sort keys %$hall_def) {
            my @types;
            for my $i (0..3) {
                my @same_glyphs = grep {$_->type eq $hall_def->{$hall}[$i]} @$glyphs;
                $types[$i] = \@same_glyphs;
            }

            while (@{$types[0]} && @{$types[1]} && @{$types[2]} && @{$types[3]}) {
                my $g0 = shift @{$types[0]};
                my $g1 = shift @{$types[1]};
                my $g2 = shift @{$types[2]};
                my $g3 = shift @{$types[3]};

                print "Assemble [".$g0->type."-".$g0->id."][".$g1->type."][".$g2->type."][".$g3->type."]\n";

                $archaeology->assemble_glyphs([$g0,$g1,$g2,$g3]);
            }
        }
    }
}

1;
