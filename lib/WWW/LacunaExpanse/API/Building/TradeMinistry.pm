package WWW::LacunaExpanse::API::Building::TradeMinistry;

use Moose;
use Carp;
use Data::Dumper;
use WWW::LacunaExpanse::API::Glyph;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes


# Push items to a colony
#   returns undef if the receiving port cannot accept any more ships
#
sub push_items {
    my ($self, $target, $items, $options) = @_;

    my $result;
    eval {
        my $result = $self->connection->call($self->url, 'push_items',[
            $self->connection->session_id, $self->id, $target->id, $items, $options]);
    };
    if ($@) {
        return;
    }

    # TODO: Should return the date the ships arrive here in a status block
    # for now just return success.
    return 1;
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
