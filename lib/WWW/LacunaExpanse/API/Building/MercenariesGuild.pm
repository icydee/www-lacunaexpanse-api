package WWW::LacunaExpanse::API::Building::MercenariesCommand;

use Moose;
use Carp;
use Data::Dumper;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::API::Plan;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes

# Get all spies that might be traded
#
sub get_spies {
    my ($self) = @_;

    my $result = $self->connection->call($self->url, 'get_spies', [$self->connection->session_id, $self->id]);
    my $spies = $result->{result}{spies};
    my @available_spies;
    for my $spy_ref (@$spies) {
        my $spy = WWW::LacunaExpanse::API::Spy->new({
            id          => $spy_ref->{id},
            name        => $spy_ref->{name},
            level       => $spy_ref->{level},
        });
        push @available_spies, $spy;
    }
    return \@available_spies;
}


# Accept a trade from the market
#
sub accept_from_market {
    my ($self, $trade_id) = @_;

    my $result = $self->connection->call($self->url, 'accept_from_market', [$self->connection->session_id, $self->id, $trade_id]);
}

# Add a trade to the market
# (returns the trade_id)
#
sub add_to_market {
    my ($self, $spy, $ask, $ship) = @_;

    my $result = $self->connection->call($self->url, 'add_to_market', [$self->connection->session_id, $self->id, $spy->id, $ask, defined $ship ? $ship->id : undef);
    my $trade_id = $result->{result}{trade_id};

    return $trade_id;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
