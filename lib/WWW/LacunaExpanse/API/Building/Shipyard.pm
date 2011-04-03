package WWW::LacunaExpanse::API::Building::Shipyard;

use Moose;
use Carp;
use Data::Dumper;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes
has 'page_number'       => (is => 'rw', default => 1);
has 'index'             => (is => 'rw', default => 0);

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
sub refresh {
    my ($self) = @_;

    $self->get_buildable;
    $self->view_build_queue;
    $self->reset_ship;
}


sub get_buildable {
    my ($self, $tag) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($self->url, 'get_buildable',[
        $self->connection->session_id, $self->id, $tag ? $tag : ()]);
    $self->connection->debug(0);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings_1);

    # other strings
    my @ships;
    for my $ship_type (keys %{$body->{buildable}}) {
        my $ship_hash = $body->{buildable}{$ship_type};

        my $cost_hash = $ship_hash->{cost};
        my $cost = WWW::LacunaExpanse::API::Cost->new({
            energy      => $cost_hash->{energy},
            food        => $cost_hash->{food},
            ore         => $cost_hash->{ore},
            seconds     => $cost_hash->{seconds},
            waste       => $cost_hash->{waste},
            water       => $cost_hash->{water},
        });

#print Dumper $ship_hash;
        my $virtual_ship = WWW::LacunaExpanse::API::VirtualShip->new({
            type        => $ship_type,
            hold_size   => 0,
            speed       => 0,
            stealth     => 0,
            cost        => $cost,
            type_human  => $ship_hash->{type_human},
            can_build   => $ship_hash->{can},
            reason_code => $ship_hash->{can} == 0 && $ship_hash->{reason} ? $ship_hash->{reason}[0] : '',
            reason_text => $ship_hash->{can} == 0 && $ship_hash->{reason} ? $ship_hash->{reason}[1] : '',
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

    eval {
        $self->connection->debug(0);
        my $result = $self->connection->call($self->url, 'build_ship',[
            $self->connection->session_id, $self->id, $ship_type]);
        $self->connection->debug(0);
    };
    if ($@) {
        print $@;
        return;
    }

    return 1;
}

# Refresh the build queue from the server
#
sub view_build_queue {
    my ($self) = @_;

    my $result = $self->connection->call($self->url, 'view_build_queue',[
        $self->connection->session_id, $self->id, $self->page_number]);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings_2);

print "ships building = ".$self->number_of_ships_building."\n";

    # other strings
    my @ships_building;
    for my $ship_hash (@{$body->{ships_building}}) {
        my $virtual_ship = WWW::LacunaExpanse::API::VirtualShip->new({
            type            => $ship_hash->{type},
            type_human      => $ship_hash->{type_human},
            date_completed  => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($ship_hash->{date_completed}),
        });
        push @ships_building, $virtual_ship;
    }
    $self->_ships_building(\@ships_building);

}

# Reset to the first record
#
sub reset_ship {
    my ($self) = @_;

    $self->index(0);
    $self->page_number(1);
}

# Return the next page of results
#
sub next_ship {
    my ($self) = @_;

    if ($self->index >= $self->number_of_ships_building) {
        return;
    }

    my $page_number = int($self->index / 25) + 1;
    if ($page_number != $self->page_number) {
        $self->page_number($page_number);
        $self->view_build_queue;
    }
    my $ship = $self->ships_building->[$self->index % 25];
    $self->index($self->index + 1);
    return $ship;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
