package WWW::LacunaExpanse::API::Star;

use Moose;
use Carp;
use Data::Dumper;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'cached'            => (is => 'ro');

my $path = '/map';

my @simple_strings  = qw(name color x y);
my @date_strings    = qw();
my @other_strings   = qw(bodies);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->update;
            return $self->$attr;
        }
    );
}

# Stringify
use overload '""' => sub {
    my $star = $_[0];
    my $str = "  Star\n";
    $str .= "    ID     : ".$star->id."\n";
    $str .= "    Name   : ".$star->name."\n";
    $str .= "    Colour : ".$star->color."\n";
    $str .= "    x      : ".$star->x."\n";
    $str .= "    y      : ".$star->y."\n";
    for my $body (@{$star->bodies}) {
        $str .= $body;
    }

    return $str;
};

# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'get_star',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $data = $result->{result}{star};

    # simple strings
    for my $attr (@simple_strings) {
        my $method = "_$attr";
        $self->$method($data->{$attr});
    }

    # date strings
    for my $attr (@date_strings) {
        my $date = $data->{$attr};
        my $method = "_$attr";
        $self->$method(WWW::LacunaExpanse::API::DateTime->from_lacuna_string($date));
    }

    # other strings
    # Bodies
    my @bodies;

    if ($data->{bodies}) {
        for my $body_hash (@{$data->{bodies}}) {

            # Ore
            my $ores_hash = $body_hash->{ore};
            my $ores;
            if ($ores_hash) {
                $ores = WWW::LacunaExpanse::API::Ores->new;
                for my $ore (qw(anthracite bauxite beryl chalcopyrite chromite fluorite galena goethite
                    gold gypsum halite kerogen magnetite methane monazite rutile sulfur trona uraninite zircon)) {
                    $ores->$ore($ores_hash->{$ore});
                }
            }

            my $star    = $self;
            my $water   = $body_hash->{water} || 0;
            my $body = WWW::LacunaExpanse::API::Body->new({
                id      => $body_hash->{id},
                name    => $body_hash->{name},
                image   => $body_hash->{image},
                orbit   => $body_hash->{orbit},
                size    => $body_hash->{size},
                type    => $body_hash->{type},
                water   => $water,
                x       => $body_hash->{x},
                y       => $body_hash->{y},
                ore     => $ores,
                empire  => $self,
                star    => $star,
            });
            push @bodies, $body;
        }
    }
    $self->_bodies(\@bodies);
}

# Find star(s) by their name
#
sub find {
    my ($class, $star_name) = @_;

    my $connection = WWW::LacunaExpanse::API::Connection->instance;

    $connection->debug(0);
    my $result = $connection->call($path, 'search_stars', [$connection->session_id, $star_name]);
    $connection->debug(0);

    my $stars;
    my $stars_hash = $result->{result}{stars};
    for my $star (@{$stars_hash}) {
        my $star = WWW::LacunaExpanse::API::Star->new({
            id      => $star->{id},
            color   => $star->{color},
            name    => $star->{name},
            x       => $star->{x},
            y       => $star->{y},
        });
        push @$stars, $star;
    }
    return $stars;
}


# Check for incoming probe
# returns undefined if no probe is arriving
#
sub check_for_incoming_probe {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'check_star_for_incoming_probe',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    # We should cache this so that it remembers the amount of time and the time of the last request
    my $arrival_time = $result->{result}{incoming_probe};
    if ($arrival_time) {
        return WWW::LacunaExpanse::API::DateTime->from_lacuna_string($result->{result}{incoming_probe});
    }
    return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
