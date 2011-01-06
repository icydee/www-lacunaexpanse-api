#!/home/icydee/localperl/bin/perl

# Script to do a one-off import of the lacuna star CSV file into your local
# SQLite database
#
# Ensure you have copied my_account.yml.template to my_account.yml and set
# up all the configuration items before you start
#
use Modern::Perl;

use FindBin qw($Bin);
use DBI;
use Text::CSV::Slurp;
use Data::Dumper;

use lib "$Bin/../lib";

main: {
    my $dbargs = {AutoCommit => 0, PrintError => 1};

    my $my_account      = YAML::Any::LoadFile("$Bin/myaccount.yml");

    my $dsn = "dbi:SQLite:dbname=$Bin/".$my_account->{db_file};

    my $dbh = DBI->connect($dsn,"","",$dbargs);

    my ($stars) = $dbh->selectrow_array('select count(*) from star');
    if ($stars) {
        die "CSV file has already been imported. To re-import first re-initialise the database\n";
    }

    my $data = Text::CSV::Slurp->load(file => "$Bin/../db/lacuna.csv");

    eval {
        for my $hash (@$data) {
            my $id      = $hash->{id};
            my $name    = $hash->{name};
            my $x       = $hash->{x};
            my $y       = $hash->{y};
            my $color   = $hash->{color};
            my $sector  = $hash->{sector};

            print "ID [$id] name [$name] x [$x] y [$y] color [$color]\t\t\t\r";
            $dbh->do("insert into star (id,name,x,y,color,sector) values ($id,'$name',$x,$y,'$color','$sector')");
        }
    };
    print "\n";
    if ($@) {
        warn "Transaction aborted - $@";
        eval { $dbh->rollback };
    }
    $dbh->commit();
    $dbh->disconnect();
}
1;
