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

# Get all glyphs that can be traded
#
sub get_glyphs {
    my ($self) = @_;

    my $result = $self->connection->call($self->url, 'get_glyphs',[$self->connection->session_id, $self->id]);

    my @glyphs;
    my $glyphs_list = $result->{result}{glyphs};
#print Dumper($result);
    for my $glyph_hash (@$glyphs_list) {
        my $glyph = WWW::LacunaExpanse::API::Glyph->new({id => $glyph_hash->{id}, type => $glyph_hash->{type}});
        push @glyphs, $glyph;
    }
    return \@glyphs;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
