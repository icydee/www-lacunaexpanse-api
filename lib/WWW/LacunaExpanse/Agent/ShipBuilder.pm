package WWW::LacunaExpanse::Agent::ShipBuilder;

use Moose;
use Carp;

use WWW::LacunaExpanse::API::DateTime;

# Agent to manage the building of ships which (typically) are 'consumed'
# such as probes, drones, fighters, excavators, etc.
# The 'required' hash determines how many of each ship the agent should
# attempt to keep built. The priority determines which one's are built
# first (lowest number = highest priority)
# The agent ensures that there is only one ship being built (by this agent)
# at a time.
# Note that the number of ships required represents all ships on the planet
# either being built, docked in any of the space_ports or travelling. It
# does not count ships which do not appear in the space_port (e.g. probes
# around stars, or deployed mining ships for example).
#

# Attributes
has 'shipyard'          => (is => 'rw');
has 'space_port'        => (is => 'rw');
has 'required'          => (is => 'rw');

# required is a hash of the requirements e.g.
#    {
#       probe   => {quantity => 6, priority => 3},
#       fighter => {quantity => 3, priority => 1},
#    }

# Change a requirement, call with a hash-ref {probe => {quantity => 3, priority => 2}
#
sub requirement {
    my ($self, $args) = @_;

    for my $type (keys %$args) {
        $self->required->{$type} = $args->{$type};
    }

    # Recheck the priorities.
    return $self->update;
}

# Update the shipyard, returns the number of seconds to wait until the next check
#
sub update {
    my ($self) = @_;

    # default is to wait 15 minutes for next update
    my $to_wait = 15 * 60 * 60;

    my $now = WWW::LacunaExpanse::API::DateTime->now;
    # If the shipyard is empty, then see what we can build next
    my $ships_building = $self->shipyard->number_of_ships_building;
    my $final_date_complete = $now;

    if ($ships_building) {
        $self->shipyard->reset_ship;

        while (my $ship_building = $self->shipyard->next_ship) {
            print "Ship being built until ".$ship_building->date_completed."\n";
            if ($ship_building->date_completed > $final_date_complete) {
                $final_date_complete = $ship_building->date_completed;
            }
        }
        # convert the time to wait into seconds
        my $dt = $final_date_complete->delta_ms($now);
        my $to_wait = $dt->minutes * 60 + $dt->seconds;
    }
    else {
        print "There are no ships being built\n";
    }
    print "We have to wait $to_wait seconds until $final_date_complete\n";
    return $to_wait;
}


# requires_resources
#   determine what resources are required, either now or soon
#   the necessary resources (cost) and time
#
sub requires_resources {
    my ($self) = @_;

    my $build_status = $self->shipyard->ship_build_status($self->ship_type);
    return $build_status->cost;
}

# can_build
#   permission is granted to build (if you can)
#
sub can_build {
    my ($self) = @_;

    my $build_status = $self->shipyard->ship_build_status($self->ship_type);
    if ( ! $build_status->can ) {
        # Can not build yet
        return;         # Can not build yet
    }

    $self->shipyard->build_ship($self->ship_type);
    return 1;
}

1;
