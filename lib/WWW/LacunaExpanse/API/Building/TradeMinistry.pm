package WWW::LacunaExpanse::API::Building::TradeMinistry;

use Moose;
use Carp;
use Data::Dumper;
use WWW::LacunaExpanse::API::Glyph;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes


# Push items to a colony
#
sub push_items {
    my ($self, $target, $items, $options) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($self->url, 'push_items',[
        $self->connection->session_id, $self->id, $target->id, $items, $options]);
    $self->connection->debug(0);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
