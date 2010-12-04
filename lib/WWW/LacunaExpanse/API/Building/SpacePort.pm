package WWW::LacunaExpanse::API::Building::SpacePort;

use Moose;
use Carp;
use Data::Dumper;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes

my @simple_strings_1    = qw(max_ships docks_available);
my @other_strings_1    = qw(docked_hash);

for my $attr (@simple_strings_1, @other_strings_1) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->get_summary;
            return $self->$attr;
        }
    );
}

# Refresh the object from the Server
#
sub get_summary {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($self->url, 'view',[
        $self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings_1);

    # other strings
    # I don't like returning a hash, but it will do for now
    $self->_docked_hash($body->{docked_ships});
}

# Return the number of docked ships
#
sub docked_ships {
    my ($self, $type) = @_;

#print Dumper(\$self->docked_hash());
    if ($type) {
        if ($self->docked_hash()->{$type}) {
            return $self->docked_hash()->{$type};
        }
        return 0;
    }
    my $ships = 0;
    map {$ships += $self->docked_hash()->{$_}} keys %{$self->docked_hash()};
    return $ships;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
