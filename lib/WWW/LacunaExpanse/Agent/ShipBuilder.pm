package WWW::LacunaExpanse::Agent::ShipBuilder;

use Moose;
use Carp;
use Data::Dumper;

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
has 'colony'            => (is => 'rw');
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

    # default is to wait 30 minutes for next update
    my $to_wait = 30 * 60;
    print "Agent::ShipBuilder - Colony ".$self->colony->name." shipyard ".$self->shipyard->x."/".$self->shipyard->y."\n";
    my $now = WWW::LacunaExpanse::API::DateTime->new;
    # If the shipyard is empty, then see what we can build next
    $self->shipyard->refresh;
    my $ships_building = $self->shipyard->number_of_ships_building;
    my $final_date_completed;

    if ($ships_building) {
        # We don't build if the shipyard is in use
        $self->shipyard->reset_ship;
        print "Can't build just yet, shipyard still in use ($ships_building)\n";

        while (my $ship_building = $self->shipyard->next_ship) {
#            print "Ship being built until ".$ship_building->date_completed."\n";
            if (! $final_date_completed || $ship_building->date_completed > $final_date_completed) {
                $final_date_completed = $ship_building->date_completed;
#                print "CHANGE: date completed to $final_date_completed\n";
            }
        }
        # convert the time to wait into seconds
        $to_wait = $final_date_completed->gps_seconds_since_epoch - $now->gps_seconds_since_epoch;
    }
    else {
        # Work out from the queue, what ship should be built next
        my @types = sort {$self->required->{$a}{priority} <=> $self->required->{$b}{priority}} keys %{$self->required};
        my @ships = $self->space_port->all_ships;

SHIP_TYPE:
        for my $type (@types) {
            # Are there sufficient of this ship type already?

            my $quantity = scalar grep {$_->type eq $type} @ships;
#            print "There are $quantity ships of type $type currently\n";
            if ($quantity < $self->required->{$type}{quantity}) {
                # Check if we can build this ship type
                my $buildable = $self->shipyard->ship_build_status($type);
#                print Dumper($buildable);
                if ($buildable->can eq 'BUILD') {
                    # Build this ship type
                    $self->shipyard->build_ship($type);
                    $self->shipyard->refresh;
                    $self->space_port->refresh;
                    print "BUILDING SHIP type $type\n";
                    last SHIP_TYPE;
                }
                else {
                    print "Cannot build ship type '$type', reason ".$buildable->reason_text."\n";
                }
            }
        }
    }
    # round down and allow a further 30 seconds delay
    $to_wait = int($to_wait) + 30;
    print "We have to wait $to_wait seconds\n";
    return $to_wait;
}

1;
