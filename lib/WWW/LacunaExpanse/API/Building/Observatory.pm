package WWW::LacunaExpanse::API::Building::Observatory;

use Moose;
use Carp;
use Data::Dumper;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes
has 'page_number'       => (is => 'rw', default => 1);
has 'index'             => (is => 'rw', default => 0);

my @simple_strings  = qw(star_count max_probes);
my @date_strings    = qw();
my @other_strings   = qw(probed_stars);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
print "observatory accessing --- $attr\n";
            $self->update_observatory;
            return $self->$attr;
        }
    );
}

# Reset to the first record
#
sub reset_probed_star {
    my ($self) = @_;

    $self->index(0);
    $self->page_number(1);
}

# Return the next page of results
#
sub next_probed_star {
    my ($self) = @_;

    if ($self->index >= $self->star_count) {
        return;
    }

    my $page_number = int($self->index / 25) + 1;
    if ($page_number != $self->page_number) {
        $self->page_number($page_number);
        $self->update_observatory;
    }
    my $star = $self->probed_stars->[$self->index % 25];
    $self->index($self->index + 1);
    return $star;
}

# Return the total number of probed stars
#
sub count_probed_stars {
    my ($self) = @_;

    return $self->star_count;
}

# Refresh the object from the Server
#
sub update_observatory {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($self->url, 'get_probed_stars',[
        $self->connection->session_id, $self->id, $self->page_number]);

    $self->connection->debug(0);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings);
    $self->date_strings($body, \@date_strings);

    # other strings
    my @probed_stars;
    for my $star_hash (@{$body->{stars}}) {
        my @bodies;

        my $star = WWW::LacunaExpanse::API::Star->new({
            id      => $star_hash->{id},
            name    => $star_hash->{name},
            color   => $star_hash->{color},
            x       => $star_hash->{x},
            y       => $star_hash->{y},
        });

        # bodies, id, name, x, y

        push @probed_stars, $star;
    }
    $self->_probed_stars(\@probed_stars);
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
