#!/home/icydee/localperl/bin/perl

# Gather stats about all empires and put the data into the database

use Modern::Perl;
use FindBin qw($Bin);
use Log::Log4perl;
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::DB;
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

MAIN: {
    Log::Log4perl::init("$Bin/../empire_rank.log4perl.conf");

    my $log = Log::Log4perl->get_logger('MAIN');

    my $my_account      = YAML::Any::LoadFile("$Bin/../myaccount.yml");

    my $mysql_config    = YAML::Any::LoadFile("$Bin/../mysql.yml");

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


    my $stats           = WWW::LacunaExpanse::API::Stats->new;
    my $empire_ranks    = $stats->empire_ranks;
    my $now             = DateTime->now;

    $log->debug("There are a total of ".scalar(@$empire_ranks)." empires");
    for my $empire_stat (@$empire_ranks) {
        $log->debug("Empire ".$empire_stat->empire->id." ".$empire_stat->empire->name);

        my $alliance_id = $empire_stat->alliance_stat->alliance_id || 0;
        if ($alliance_id) {
            my ($db_alliance) = $schema->resultset('AllianceStat')->find_or_create({
                server_id       => 1,
                alliance_id     => $empire_stat->alliance_stat->alliance_id,
                on_date         => $now,
                alliance_name   => $empire_stat->alliance_stat->alliance_name,
            });
        }

        my ($db_empire_rank) = $schema->resultset('EmpireRank')->create({
            server_id               => 1,
            empire_id               => $empire_stat->empire->id,
            alliance_id             => $alliance_id,
            on_date                 => $now,
            empire_name             => $empire_stat->empire->name,
            colony_count            => $empire_stat->colony_count,
            population              => $empire_stat->population,
            empire_size             => $empire_stat->empire_size,
            building_count          => $empire_stat->building_count,
            average_building_level  => $empire_stat->average_building_level,
            offense_success_rate    => $empire_stat->offense_success_rate,
            defense_success_rate    => $empire_stat->defense_success_rate,
            dirtiest                => $empire_stat->dirtiest,
        });
    }
}

1;
