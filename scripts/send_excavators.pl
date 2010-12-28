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

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

my $my_empire = $api->my_empire;
my $centre_star = $api->find({ star => $centre_star_name }) || die "Cannot find star ($centre_star_name)";

########################################################################
### Ensure we have calculated all the distances from the centre body ###
########################################################################

# We calculate the distance from the central star to all other stars in the
# universe and hold the distances in the SQL database. This makes it easier
# to determine the next closest star with a simple query
#
# NOTE: this can take a little while, but it is only needed once for each
# search loci.
#
my $distance_count  = $schema->resultset('Distance')->search({from_id => $centre_star->id})->count;
my $star_count      = $schema->resultset('Star')->search()->count;
#print "Distance_count=$distance_count star_count=$star_count\n";

if ($distance_count != $star_count) {
    # Re-initialise the distance table
    $schema->resultset('Distance')->search({from_id => $centre_star->id})->delete;
    my $star_rs = $schema->resultset('Star')->search_rs({});

    while (my $star = $star_rs->next) {
        my $distance = int(sqrt(($star->x - $centre_star->x)**2 + ($star->y - $centre_star->y)**2));
        $schema->resultset('Distance')->create({
            from_id     => $centre_star->id,
            to_id       => $star->id,
            distance    => $distance,
        });
        print "[".$star->id."]\tDistance to star ".$star->name." (".$star->x."|".$star->y.") is $distance\n" ;
    }
}

# This script is intended to be run continuously. To stop it hit ctrl-c
#
RESCAN:
while (1) {

    # Get a result set of stars ordered by distance

    my $distance_rs = $schema->resultset('Distance')->search_rs({
        from_id             => $centre_star->id,
        'to_star.status'    => 3,
        }
        ,{
            join        => 'to_star',
            order_by    => 'distance',
        });
    my $distance    = $distance_rs->first;
    if ($distance) {
        my $star        = $distance->to_star;
        my $body_rs     = $star->bodies;
        my $body        = $body_rs->first;

        # Find all colonies which have excavators
        my @colonies = @{$my_empire->colonies};

COLONY:
        for my $colony (@colonies) {
            my $space_port = $colony->space_port;

            next COLONY if ! $space_port;

            $space_port->refresh;
            my @excavators = grep {$_->task eq 'Docked'} $space_port->all_ships('excavator');
            print "Colony ".$colony->name." has ".scalar(@excavators)." docked excavators\n";

            # Send to a body around the next closest star
EXCAVATOR:
            while ($distance && @excavators) {
                print "checking next closest body\n";
                if ( ! $body ) {
                    # Mark the star as exhausted, the probe can be abandoned
                    print "Star ".$star->name." has no more unexcavated bodies\n";

                    $star->status(4);
                    $star->update;
                    $distance   = $distance_rs->next;
                    last EXCAVATOR unless $distance;

                    $star       = $distance->to_star;
                    $body_rs    = $star->bodies;
                    $body       = $body_rs->first;
                    next EXCAVATOR;
                }
                # If the body is occupied, ignore it
                if ($body->empire_id) {
                    print "Body ".$body->name." is occupied, ignore it\n";
                    $body = $body_rs->next;
                    if ( ! $body ) {
                        next EXCAVATOR;
                    }
                }

                print "Trying to send to ".$body->name."\n";
                # Get all excavators that can be sent to this planet
                my @excavators = grep {$_->type eq 'excavator'} @{$space_port->get_available_ships_for({ body_id => $body->id })};
                if ( ! @excavators ) {
                    @excavators = grep {$_->task eq 'Docked'} $space_port->all_ships('excavator');
                    if ( ! @excavators) {
                        # No more excavators at this colony
                        print "No more excavators to send from ".$colony->name."\n";
                        next COLONY;
                    }
                    print "Can't send excavators to ".$body->name."\n";
                    $body = $body_rs->next;
                    next EXCAVATOR;
                }

                my $first_excavator = $excavators[0];
                $space_port->send_ship($first_excavator->id, {body_id => $body->id});
                @excavators = grep {$_->id != $first_excavator->id} @excavators;
                $space_port->refresh;
                $body = $body_rs->next;
            }
        }
    }
    print "SENDING EXCAVATORS again in 30 minutes\n\n";
    sleep(30 * 60);
}


1;
