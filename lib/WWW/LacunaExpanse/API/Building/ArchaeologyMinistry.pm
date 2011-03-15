package WWW::LacunaExpanse::API::Building::ArchaeologyMinistry;

use Moose;
use Carp;
use Data::Dumper;
use WWW::LacunaExpanse::API::Ore;
use WWW::LacunaExpanse::API::Glyph;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes
has 'page_number'       => (is => 'rw', default => 1);
has 'index'             => (is => 'rw', default => 0);

my @simple_strings  = qw();
my @other_strings   = qw(glyphs);

for my $attr (@simple_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->get_glyphs;
            return $self->$attr;
        }
    );
}

# Refresh the object from the Server
#
sub refresh {
    my ($self) = @_;

    $self->get_glyphs;
}

# Get all glyphs as a list reference.
#
sub get_glyphs {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($self->url, 'get_glyphs',[
        $self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings);

    # other strings
    my @glyphs;
    for my $glyph_hash (@{$body->{glyphs}}) {
        my $glyph = WWW::LacunaExpanse::API::Glyph->new({
            id      => $glyph_hash->{id},
            type    => $glyph_hash->{type},
        });
        push @glyphs, $glyph;
    }
    $self->_glyphs(\@glyphs);
}

# Assemble glyphs
#
sub assemble_glyphs {
    my ($self, $glyphs) = @_;

    my @glyph_ids = map {$_->id} @$glyphs;
    my $result = $self->connection->call(
	$self->url, 'assemble_glyphs', [
	    $self->connection->session_id, $self->id, \@glyph_ids
	]);

    return $result->{item_name};
}


# Get all glyphs as a summary
#
#   e.g. {anthracite => 2, bauxite => 1}
#
sub get_glyph_summary {
    my ($self) = @_;
    my $glyph_count;

    for my $glyph (@{$self->glyphs}) {
        my $glyph_type = $glyph->type;
        $glyph_count->{$glyph_type}  = $glyph_count->{$glyph_type} ? $glyph_count->{$glyph_type}  + 1 : 1;
    }
    return $glyph_count;
}

# Search for a particular glyph type
#
sub search_for_glyph {
    my ($self, $ore_type) = @_;

    eval {
        my $result = $self->connection->call($self->url, 'search_for_glyph',[
	        $self->connection->session_id, $self->id, $ore_type
        ]);
    };
    if ($@) {
        print STDERR $@;
        return;
    }

    return 1;
}

# Get all ores available for processing
#
sub get_ores_available_for_processing {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($self->url, 'get_ores_available_for_processing', [
	    $self->connection->session_id, $self->id
    ]);
    $self->connection->debug(0);

    my @ores;
    for my $ore_type (%{$result->{result}{ore}}) {
        my $ore = WWW::LacunaExpanse::API::Ore->new({
            type        => $ore_type,
            quantity    => $result->{result}{ore}{$ore_type},
        });
        push @ores, $ore;
    }
    return \@ores;
}

# Subsidize a search with essentia
#
sub subsidize_search {
    my ($self) = @_;

    my $result = $self->connection->call($self->url, 'subsidize_search', [
        $self->connection->session_id, $self->id
    ]);

    return $result->{building};
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
