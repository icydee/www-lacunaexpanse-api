package WWW::LacunaExpanse::API::MyColony;

use Moose;
use Carp;

extends 'WWW::LacunaExpanse::API::Colony';

my $path = '/body';

my @simple_strings  = qw(needs_surface_refresh building_count plots_available happiness happiness_hour
    food_stored food_capacity food_hour energy_stored energy_capacity energy_hour ore_stored
    ore_capacity ore_hour water_stored water_capacity water_hour waste_stored waste_capacity
    waste_hour);
my @date_strings    = qw();
my @other_strings   = qw(incoming_foreign_ships);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->update_colony;
            return $self->$attr;
        }
    );
}

# Refresh the object from the Server
#
sub update_colony {
    my ($self) = @_;

#    $self->connection->debug(1);
    my $result = $self->connection->call($path, 'get_status',[$self->connection->session_id, $self->id]);
    $self->connection->debug(1);

    my $body = $result->{result}{body};

    $self->simple_strings($body, \@simple_strings);

    $self->date_strings($body, \@date_strings);

    # other strings
    # Incoming Foreign Ships

}

1;
