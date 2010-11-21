#!/home/icydee/localperl/bin/perl

use DBI;
use strict;
use warnings;

use Text::CSV::Slurp;
use Data::Dumper;

main: {
    my $dbargs = {AutoCommit => 0, PrintError => 1};

    my $dbh = DBI->connect("dbi:SQLite:dbname=lacuna.db","","",$dbargs);


    my $data = Text::CSV::Slurp->load(file => 'lacuna.csv');

    eval {
        for my $hash (@$data) {
            my $id      = $hash->{id};
            my $name    = $hash->{name};
            my $x       = $hash->{x};
            my $y       = $hash->{y};
            my $color   = $hash->{color};

            print "ID [$id] name [$name] x [$x] y [$y] color [$color]\n";
            $dbh->do("insert into star (id,name,x,y,color) values ($id,'$name',$x,$y,'$color')");
        }
    };
    if ($@) {
        warn "Transaction aborted - $@";
        eval { $dbh->rollback };
    }
    $dbh->commit();
    $dbh->disconnect();

}
