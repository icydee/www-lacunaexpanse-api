#!/home/icydee/localperl/bin/perl

# Script to do a one-off import of the lacuna star CSV file into your local
# SQLite database
#
# Ensure you have copied my_account.yml.template to my_account.yml and set
# up all the configuration items before you start
#
use Modern::Perl;

use FindBin::libs;
use FindBin qw($Bin);

use YAML::Any;
use Text::CSV::Slurp;
use Data::Dumper;

use WWW::LacunaExpanse::DB;

main: {
    my $mysql   = YAML::Any::LoadFile("$Bin/../mysql.yml");

    my $schema = WWW::LacunaExpanse::DB->connect(
        $mysql->{dsn},
        $mysql->{username},
        $mysql->{password},
        {AutoCommit => 0, PrintError => 1},
    );

    my $stars_rs = $schema->resultset('Star');
    my $stars = $stars_rs->count;
    if ($stars > 0) {
        die "CSV file has already been imported. To re-import, first re-initialise the database\n";
    }

    print "Slurping CSV file\n";
    my $data = Text::CSV::Slurp->load(file => "$Bin/../db/lacuna.csv");

    eval {
        for my $hash (@$data) {
            my $id      = $hash->{id};
            my $name    = $hash->{name};
            my $x       = $hash->{x};
            my $y       = $hash->{y};
            my $color   = $hash->{color};
            my $sector  = $hash->{sector};

            print "ID [$id] name [$name] x [$x] y [$y] color [$color]\n";
            $stars_rs->create({
                server_id   => 1,
                star_id     => $id,
                name        => $name,
                x           => $x,
                y           => $y,
                color       => $color,
                sector      => $sector,
            });
        }
    };
    print "\n";
    if ($@) {
        warn "Transaction aborted - $@";
    }
}
1;
