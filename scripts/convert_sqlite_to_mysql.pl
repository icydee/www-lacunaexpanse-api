#!/home/icydee/localperl/bin/perl

# One-off script to import the database created by sqlite into mysql
#
use Modern::Perl;

use FindBin::libs;
use FindBin qw($Bin);

use Log::Log4perl;
use YAML::Any;
use Text::CSV::Slurp;
use Data::Dumper;
use DateTime;

use WWW::LacunaExpanse::DB;
use WWW::LacunaExpanse::Schema;

main: {
    Log::Log4perl::init("$Bin/../convert.log4perl.conf");

    my $log = Log::Log4perl->get_logger('main');
    $log->info('Program start');

    my $config_mysql    = YAML::Any::LoadFile("$Bin/../mysql.yml");
    my $config_sqlite   = YAML::Any::LoadFile("$Bin/../myaccount.yml");
    my $empire_id       = 945;

    my $mysql_schema = WWW::LacunaExpanse::DB->connect(
        $config_mysql->{dsn},
        $config_mysql->{username},
        $config_mysql->{password},
        {AutoCommit => 1, PrintError => 1},
    );

    my $dsn             = "dbi:SQLite:dbname=$Bin/".$config_sqlite->{db_file};
    my $sqlite_schema   = WWW::LacunaExpanse::Schema->connect($dsn);

    # Bodies
#    my $lite_body_rs = $sqlite_schema->resultset('Body')->search({},{order_by => 'id'});
#    while (my $lite_body = $lite_body_rs->next) {
#        $log->debug("converting body ".$lite_body->id);
#        my $my_body = $mysql_schema->resultset('Body')->create({
#            server_id   => 1,
#            body_id     => $lite_body->id,
#            orbit       => $lite_body->orbit,
#            name        => $lite_body->name,
#            x           => $lite_body->x,
#            y           => $lite_body->y,
#            image       => $lite_body->image,
#            size        => $lite_body->size,
#            type        => $lite_body->type,
#            star_id     => $lite_body->star_id,
#            empire_id   => $lite_body->empire_id,
#            water       => $lite_body->water,
#        })
#    }

    my $my_exc_rs   = $mysql_schema->resultset('Excavation')->search({}, {order_by => 'on_date'});
    my $my_exc_rs2  = $mysql_schema->resultset('ExcavationTwo');
    while (my $my_exc = $my_exc_rs->next) {
        $my_exc_rs2->create({
            server_id       => $my_exc->server_id,
            empire_id       => $my_exc->empire_id,
            body_id         => $my_exc->body_id,
            on_date         => $my_exc->on_date,
            colony_id       => $my_exc->colony_id,
            resource_genre  => $my_exc->resource_genre,
            resource_type   => $my_exc->resource_type,
            resource_qty    => $my_exc->resource_qty,
        });
    }

    # Links between bodies and ores
#    my $lite_rs = $sqlite_schema->resultset('LinkBodyOre')->search({}, {order_by => 'id'});
#    while (my $lite_link = $lite_rs->next) {
#        $log->debug("Converting Link Body to Ore ".$lite_link->id);
#        my $my_link = $mysql_schema->resultset('LinkBodyOre')->create({
#            server_id   => 1,
#            body_id     => $lite_link->body_id,
#            ore_id      => $lite_link->ore_id,
#            quantity    => $lite_link->quantity,
#        });
#    }

    # excavations
#    my $lite_exc_rs = $sqlite_schema->resultset('Excavation')->search({},{order_by => 'id'});
#    while (my $lite_exc = $lite_exc_rs->next) {
#        $log->debug("Converting excavation ".$lite_exc->id);
#        # Convert sqlite string into a DateTime object
#        my ($year,$month,$day,$hour,$minute,$second) = $lite_exc->on_date =~ m/(\d+)\/(\d+)\/(\d+) (\d+):(\d+):(\d+)/;
#        my $on_date = DateTime->new(
#            year    => $year,
#            month   => $month,
#            day     => $day,
#            hour    => $hour,
#            minute  => $minute,
#            second  => $second,
#        );
#
#        # catch duplicates
#        eval {
#            my $my_exc = $mysql_schema->resultset('Excavation')->create({
#                server_id       => 1,
#                empire_id       => $empire_id,
#                body_id         => $lite_exc->body_id,
#                on_date         => $on_date,
#                resource_genre  => $lite_exc->resource_genre,
#                resource_type   => $lite_exc->resource_type,
#                resource_qty    => $lite_exc->resource_qty,
#            });
#        };
#
#    }
}
1;
