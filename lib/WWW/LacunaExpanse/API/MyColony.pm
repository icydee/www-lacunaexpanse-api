package WWW::LacunaExpanse::API::MyColony;

use Moose;
use Carp;
use Data::Dumper;

extends 'WWW::LacunaExpanse::API::Colony';

my $path = '/body';

has buildings => (is => 'ro', lazy_build => 1);

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

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'get_status',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result}{body};

    $self->simple_strings($body, \@simple_strings);

    $self->date_strings($body, \@date_strings);

    # other strings
    # Incoming Foreign Ships
}

# Get a list of buildings (if any)
#
sub _build_buildings {
    my ($self) = @_;

    my @buildings;

    if ($self->building_count) {
        $self->connection->debug(0);
        my $result = $self->connection->call($path, 'get_buildings',[$self->connection->session_id, $self->id]);
        $self->connection->debug(0);

        my $body = $result->{result}{buildings};
        for my $id (keys %$body) {

            my $hash = $body->{$id};
            my $pending_build;
            if ($hash->{pending_build}) {
                $pending_build = WWW::LacunaExpanse::API::Building::Timer->new({
                    remaining   => $hash->{pending_build}{seconds_remaining},
                    start       => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($hash->{pending_build}{start}),
                    end         => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($hash->{pending_build}{end}),
                });
            }

            my $work;
            if ($hash->{work}) {
                $work = WWW::LacunaExpanse::API::Building::Timer->new({
                    remaining   => $hash->{work}{seconds_remaining},
                    start       => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($hash->{work}{start}),
                    end         => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($hash->{work}{end}),
                });
            }

            my $name = $body->{$id}{name};
            $name =~ s/ //g;

            # Call the Factory to make the Building object
            my $building = WWW::LacunaExpanse::API::BuildingFactory->create(
                $name, {
                    id              => $id,
                    name            => $hash->{name},
                    x               => $hash->{x},
                    y               => $hash->{y},
                    url             => $hash->{url},
                    level           => $hash->{level},
                    image           => $hash->{image},
                    efficiency      => $hash->{efficiency},
                    pending_build   => $pending_build,
                    work            => $work,
                }
            );
            push @buildings, $building;
        }
    }
    return \@buildings;
}

# Return the (first) space port for this colony
#
sub space_port {
    my ($self) = @_;

    my ($space_port) = grep {$_->name eq 'Space Port'} @{$self->buildings};
    return $space_port;
}

# Return the (first) observatory for this colony
#
sub observatory {
    my ($self) = @_;

    my ($observatory) = grep {$_->name eq 'Observatory'} @{$self->buildings};
    return $observatory;
}

# Return the (first) shipyard for this colony
#
sub shipyard {
    my ($self) = @_;

    my ($shipyard) = grep {$_->name eq 'Shipyard'} @{$self->buildings};
    return $shipyard;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
