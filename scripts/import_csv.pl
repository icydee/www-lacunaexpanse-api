#!/home/icydee/localperl/bin/perl

use Modern::Perl;

use FindBin qw($Bin);
use DBI;
use Text::CSV::Slurp;
use Data::Dumper;

use lib "$Bin/../lib";

#
# Run once script to import the Star CSV file into an empty database
#

main: {
    my $dbargs = {AutoCommit => 0, PrintError => 1};

    my $dbh = DBI->connect("dbi:SQLite:dbname=$Bin/../db/lacuna.db","","",$dbargs);

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

            print "ID [$id] name [$name] x [$x] y [$y] color [$color]\n";
            $dbh->do("insert into star (id,name,x,y,color,sector) values ($id,'$name',$x,$y,'$color','$sector')");
        }
    };
    if ($@) {
        warn "Transaction aborted - $@";
        eval { $dbh->rollback };
    }
    $dbh->commit();
    $dbh->disconnect();

}
