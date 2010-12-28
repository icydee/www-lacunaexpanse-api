package WWW::LacunaExpanse::API::Building::ArchaeologyMinistry;

use Moose;
use Carp;
use Data::Dumper;
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

# Refresh the object from the Server
#
sub refresh {
    my ($self) = @_;

    $self->get_glyphs;
}

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

no Moose;
__PACKAGE__->meta->make_immutable;
1;
