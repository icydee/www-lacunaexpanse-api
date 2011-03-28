#!/home/icydee/localperl/bin/perl

use Modern::Perl;
use FindBin qw($Bin);
use Log::Log4perl;
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../glyph_manager.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');
    $log->info('Program start');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

    my $api = WWW::LacunaExpanse::API->new({
        uri         => $my_account->{uri},
        username    => $my_account->{username},
        password    => $my_account->{password},
        debug_hits  => $my_account->{debug_hits},
    });

    my $dsn     = "dbi:SQLite:dbname=$Bin/../db/lacuna_test.db";
    my $schema  = WWW::LacunaExpanse::Schema->connect($dsn);

    my $star_visit;
    
    my $excavation_rs = $schema->resultset('Excavation')->search;
    while (my $excavation = $excavation_rs->next) {
        my $date    = $excavation->on_date;
        my $star_id = $excavation->body->star_id;
        if ($star_visit->{$star_id}) {
            # take the most recent visit date of bodies around the star
            if ($star_visit->{$star_id} lt $date) {
                $star_visit->{$star_id} = $date;
            }
        }
        else {
            $star_visit->{$star_id} = $date;
        }
    }
    
    # Now create entries is the ProbeVisit table
    for my $star_id (keys %$star_visit) {
        print "INSERT: star_id='$star_id' on date '".$star_visit->{$star_id}."'\n";
        $schema->resultset('ProbeVisit')->create({
            star_id => $star_id,
            on_date => $star_visit->{$star_id},
        });
    }
}

1;
