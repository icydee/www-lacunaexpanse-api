#!/home/icydee/localperl/bin/perl

# Script to convert the dates received from emails from the
# format yyyymmddhhmmss to yyyy/mm/dd hh:mm:ss as used more
# recently

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

MAIN: {
    # Load configurations

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

    my $dsn = "dbi:SQLite:dbname=$Bin/".$my_account->{db_file};

    my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

    my $excavation_rs = $schema->resultset('Excavation')->search;
    while (my $excavation = $excavation_rs->next) {
        my $date = $excavation->on_date;
        my ($year,$month,$day,$hour,$minute,$second) = $date =~ m/(^\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/;
        if ($year) {
            my $new_date = "$year/$month/$day $hour:$minute:$second";
            print "From: $date To: $new_date\n";
            $excavation->on_date($new_date);
            $excavation->update;
        }
        else {
#            print "CORRECT: $date\n";
        }
    }
}
1;
