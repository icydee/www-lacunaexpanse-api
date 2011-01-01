#!/home/icydee/localperl/bin/perl

# Script to send out excavators to bodies
#
# Send out excavators to bodies that have a probe and which have not yet been
# visited (or at least not in the last 30 days)
#

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;

#### Configuration ####
my $username                = 'icydee';
my $password                = 'secret';

my $uri                     = 'https://us1.lacunaexpanse.com';
my $dsn                     = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

my $centre_star_name        = 'Lio Easphai';    # Name of star to act as centre of search pattern
my $probe_colony_name       = 'icydee 4';       # Colony to devote to sending out probes
my @excavator_colony_names  = ('icydee 5','icydee 6','icydee 7','icydee 8');

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

my $my_empire = $api->my_empire;
my $centre_star = $api->find({ star => $centre_star_name }) || die "Cannot find star ($centre_star_name)";

# This script is intended to be run continuously. To stop it hit ctrl-c
#

# Find all colonies which have excavators
my @colonies;
for my $colony (@{$my_empire->colonies}) {
    if (grep {$_ eq $colony->name} @excavator_colony_names) {
        push @colonies, $colony;
    }
}

my ($probe_colony)  = grep {$_->name eq $probe_colony_name} @{$my_empire->colonies};
my $observatory     = $probe_colony->observatory;

RESCAN:
while (1) {

    $observatory->refresh;
    my $probed_star = $observatory->next_probed_star;
    if ($probed_star) {

        my ($db_star, $db_body_rs, $db_body);

        _save_probe_data($schema, $probed_star, 3);
        $db_star    = $schema->resultset('Star')->find($probed_star->id);
        $db_body_rs = $db_star->bodies;
        $db_body    = $db_body_rs->first;

COLONY:
        for my $colony (sort {$a->name cmp $b->name} @colonies) {

            my $space_port  = $colony->space_port;
            next COLONY if ! $space_port;
            my @excavators;

            $space_port->refresh;

            @excavators = $space_port->all_ships('excavator','Docked');
            print "Colony ".$colony->name." has ".scalar(@excavators)." docked excavators\n";
            next COLONY unless @excavators;

            # Send to a body around the next closest star
EXCAVATOR:
            while (@excavators && $probed_star) {
                print "checking next closest body ".$probed_star->name."\n";
                if ( ! $db_body ) {
                    # Mark the star as exhausted, the probe can be abandoned
                    print "Star ".$probed_star->name." has no more unexcavated bodies\n";
                    $db_star->status(5);
                    $db_star->update;
                    $observatory->abandon_probe($probed_star->id);
                    $observatory->refresh;

                    $probed_star = $observatory->next_probed_star;
                    last EXCAVATOR unless $probed_star;

                    _save_probe_data($schema, $probed_star);
                    $db_star    = $schema->resultset('Star')->find($probed_star->id);
                    $db_body_rs = $db_star->bodies;
                    $db_body    = $db_body_rs->first;

                    next EXCAVATOR;
                }
                # If the body is occupied, ignore it
                if ($db_body->empire_id) {
                    print "Body ".$db_body->name." is occupied, ignore it\n";
                    $db_body = $db_body_rs->next;
                    if ( ! $db_body ) {
                        next EXCAVATOR;
                    }
                }

                print "Trying to send to ".$db_body->name."\n";
                # Get all excavators that can be sent to this planet
                my @excavators = grep {$_->type eq 'excavator'} @{$space_port->get_available_ships_for({ body_id => $db_body->id })};

                if ( ! @excavators ) {
                    @excavators = $space_port->all_ships('excavator','Docked');

                    print "Colony XXX ".$colony->name." has ".scalar(@excavators)." docked excavators\n";
                    if ( ! @excavators) {
                        # No more excavators at this colony
                        print "No more excavators to send from ".$colony->name."\n";
                        next COLONY;
                    }
                    print "Can't send excavators to ".$db_body->name."\n";
                    $db_body = $db_body_rs->next;
                    next EXCAVATOR;
                }

                my $first_excavator = $excavators[0];
                $space_port->send_ship($first_excavator->id, {body_id => $db_body->id});
                @excavators = grep {$_->id != $first_excavator->id} @excavators;
                $space_port->refresh;
                $db_body = $db_body_rs->next;
            }
        }
    }
    print "SENDING EXCAVATORS again in 60 minutes\n\n";
    sleep(60 * 60);
}

# Save probe data in database

sub _save_probe_data {
    my ($schema, $probed_star) = @_;

    # See if we have previously probed this star
    my $db_star = $schema->resultset('Star')->find($probed_star->id);

    if ($db_star->scan_date) {
        print "Previously scanned [".$db_star->name."]. Don't scan again\n";
        if ($db_star->status == 1) {
            $db_star->status(3);
            $db_star->update;
        }
    }
    else {
        print "Saving scanned data for [".$db_star->name."]\n";
        for my $body (@{$probed_star->bodies}) {
            my $db_body = $schema->resultset('Body')->find($body->id);
            if ( $db_body ) {
                # We already have the body data, just update the empire data
                $db_body->empire_id($body->empire ? $body->empire->id : undef);
                $db_body->update;
            }
            else {
                # We need to create it
                my $db_body = $schema->resultset('Body')->create({
                    id          => $body->id,
                    name        => $body->name,
                    x           => $body->x,
                    y           => $body->y,
                    image       => $body->image,
                    size        => $body->size,
                    type        => $body->type,
                    star_id     => $probed_star->id,
                    empire_id   => $body->empire ? $body->empire->id : undef,
                    water       => $body->water,
                });
                # Check the ores for this body
                my $body_ore = $body->ore;
                for my $ore_name (WWW::LacunaExpanse::API::Ores->ore_names) {
                    # we only store ore data if the quantity is greater than 1
                    if ($body_ore->$ore_name > 1) {
                        my $db_ore = $schema->resultset('LinkBodyOre')->create({
                            ore_id      => WWW::LacunaExpanse::API::Ores->ore_index($ore_name),
                            body_id     => $db_body->id,
                            quantity    => $body_ore->$ore_name,
                        });
                    }
                }

            }
        }
        $db_star->scan_date(DateTime->now);
        $db_star->status(3);
        $db_star->empire_id($api->my_empire->id);
        $db_star->update;
    }
}

1;
