#!/home/icydee/localperl/bin/perl

# Script to fix the missing 'orbit' field in the database.
#
# Generally, the body name will be the star name with the orbit number appended
# unless the body has been renamed, in which case it still may be possible to
# work out the orbit from it's relative ID
#
use Modern::Perl;

use FindBin qw($Bin);
use DBI;
use YAML::Any;
use Text::CSV::Slurp;
use Data::Dumper;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;


main: {
    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

    my $dsn = "dbi:SQLite:dbname=$Bin/".$my_account->{db_file};

    my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

    my $body_rs = $schema->resultset('Body')->search({},{order_by => 'id'});

    my $prev_body;
    my $next_body;
    my @unknown_orbit;

    while (my $body = $body_rs->next) {
        my $star_name = $body->star->name;
        my $body_name = $body->name;

        my ($orbit) = $body_name =~ m/^$star_name\s(\d)$/;
        if ( $orbit ) {
            $body->update({orbit => $orbit});
        }
        else {
            my $unknown = {
                prev    => $prev_body,
                this    => $body,
            };
            push @unknown_orbit, $unknown;
#            print "Body ".$body->id." ".$body->name."\n";
        }
        # see if we are one after an unknown
        my ($prev_unknown) = grep {$prev_body && ($_->{this}->id == $prev_body->id)} @unknown_orbit;
        if ($prev_unknown) {
            # we are one after a previously unknown orbit
            $prev_unknown->{next} = $body;
        }
        $prev_body = $body;
    }

    for my $unknown (@unknown_orbit) {
        my $prev_body       = $unknown->{prev};
        my $this_body       = $unknown->{this};
        my $next_body       = $unknown->{next};

        my $prev_star_name  = $prev_body->star->name;
        my $this_star_name  = $this_body->star->name;
        my $next_star_name  = $next_body->star->name;

        my ($prev_orbit)    = $prev_body->name =~ m/^$prev_star_name\s(\d)$/;
        my ($next_orbit)    = $next_body->name =~ m/^$next_star_name\s(\d)$/;

        if ($next_orbit == 2 && $this_body->star_id == $next_body->star_id) {
            print "ORBIT: 1 ".$prev_body->name."/".$this_body->name."/".$next_body->name."\n";
            $this_body->update({orbit => 1});
        }
        elsif ($prev_orbit == 7 && $prev_body->star_id == $this_body->star_id) {
            print "ORBIT: 8 ".$prev_body->name."/".$this_body->name."/".$next_body->name."\n";
            $this_body->update({orbit => 8});
        }
        elsif ($prev_orbit + 2 == $next_orbit && $prev_body->star_id == $this_body->star_id) {
            print "ORBIT: ".($prev_orbit + 1)." ".$prev_body->name."/".$this_body->name."/".$next_body->name."\n";
            $this_body->update({orbit => $prev_orbit + 1});
        }
        else {
            print "UNKNOWN: ".$unknown->{this}->name." PREVIOUS ".$unknown->{prev}->name." NEXT ".$unknown->{next}->name."\n";
        }
    }

}


1;
