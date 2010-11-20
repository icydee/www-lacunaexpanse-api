package WWW::LacunaExpanse::API::Star;

use Moose;
use Carp;

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'connection'        => (is => 'ro', lazy_build => 1);
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

sub _build_connection {
    my ($self) = @_;

    return WWW::LacunaExpanse::API::Connection->instance;
}

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
                for my $ore (qw(anthracite bauxite beryl chalcopyrite chromite flourite galena goethite
                    gold gypsum halite kerogen magnetite methane monazite rutile sulfur trona uraninite zircon)) {
                    $ores->$ore($ores_hash->{$ore});
                }
            }

            my $star    = $self;
            my $body = WWW::LacunaExpanse::API::Body->new({
                id      => $body_hash->{id},
                name    => $body_hash->{name},
                image   => $body_hash->{image},
                orbit   => $body_hash->{orbit},
                size    => $body_hash->{size},
                type    => $body_hash->{type},
                water   => $body_hash->{water},
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
        $str .= "      $body\n";
    }

    return $str;
};

1;
