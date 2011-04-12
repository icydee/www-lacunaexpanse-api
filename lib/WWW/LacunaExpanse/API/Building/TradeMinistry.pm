package WWW::LacunaExpanse::API::Building::TradeMinistry;

use Moose;
use Carp;
use Data::Dumper;
use WWW::LacunaExpanse::API::Glyph;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes

my @simple_strings_1    = qw(cargo_space_used_each);
my @other_strings_1     = qw(plans);

for my $attr (@simple_strings_1, @other_strings_1) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->get_plans;
            return $self->$attr;
        }
    );
}

sub get_plans {
    my ($self) = @_;

    my $result = $self->connection->call($self->url, 'get_plans',[
        $self->connection->session_id, $self->id]);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings_1);

    # other strings
    my @plans;
    for my $plan_hash (@{$body->{plans}}) {
        my $plan = WWW::LacunaExpanse::API::Plan->new({
            id                  => $plan_hash->{id},
            name                => $plan_hash->{name},
            level               => $plan_hash->{level},
            extra_build_level   => $plan_hash->{extra_build_level},
        });

        push @plans, $plan;
    }
    $self->_plans(\@plans);
}

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
