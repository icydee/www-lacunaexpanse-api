package WWW::LacunaExpanse::API::Building::Shipyard;

use Moose;
use Carp;
use Data::Dumper;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes

my @simple_strings_1    = qw(docks_available);
my @simple_strings_2    = qw(number_of_ships_building cost_to_subsidize);
my @other_strings_1     = qw(buildable);
my @other_strings_2     = qw(ships_building);

for my $attr (@simple_strings_1, @other_strings_1) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->get_buildable;
            return $self->$attr;
        }
    );
}

for my $attr (@simple_strings_2, @other_strings_2) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->view_build_queue;
            return $self->$attr;
        }
    );
}

# Refresh the object from the Server
#
sub get_buildable {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($self->url, 'get_buildable',[
        $self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings_1);

    # other strings
    my @ships;
    for my $ship_type (keys %{$body->{buildable}}) {
        my $ship_hash = $body->{buildabl}{$ship_type};

        my $cost_hash = $ship_hash->{cost};
        my $cost = WWW::LacunaExpanse::API::Cost->new({
            energy      => $cost_hash->{energy},
            food        => $cost_hash->{food},
            ore         => $cost_hash->{ore},
            seconds     => $cost_hash->{seconds},
            waste       => $cost_hash->{waste},
            water       => $cost_hash->{water},
        });

        my $virtual_ship = WWW::LacunaExpanse::API::VirtualShip->new({
            type        => $ship_type,
            hold_size   => 0,
            speed       => 0,
            stealth     => 0,
            cost        => $cost,
            type_human  => $ship_hash->{type_human},
            can         => $ship_hash->{can},
            reason_code => $ship_hash->{can} ? $ship_hash->{reason}[0] : '',
            reason_text => $ship_hash->{can} ? $ship_hash->{reason}[1] : '',
        });
        push @ships, $virtual_ship;
    }
    $self->_buildable(\@ships);
}

#  Get the buildable status of a particular ship type
#
sub ship_build_status {
    my ($self, $ship_type) = @_;

    my ($virtual_status) = grep {$_->type eq $ship_type} @{$self->buildable};
    return $virtual_status;
}

# Build a ship
#
sub build_ship {
    my ($self, $ship_type) = @_;

    $self->connection->debug(1);
    my $result = $self->connection->call($self->url, 'build_ship',[
        $self->connection->session_id, $self->id, $ship_type]);
    $self->connection->debug(0);
}

# Refresh the build queue from the server
#
sub view_build_queue {
    my ($self) = @_;


}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
