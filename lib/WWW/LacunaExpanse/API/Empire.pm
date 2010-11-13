package WWW::LacunaExpanse::API::Empire;

use Moose;
use Carp;

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'connection'        => (is => 'ro', lazy_build => 1);
has 'cached'            => (is => 'ro');

my $path = '/empire';

my @simple_strings  = qw(alignment is_isolationist description name city country colony_count player_name skype species status_message);
my @date_strings    = qw(date_founded last_login);
my @other_strings   = qw(alliance known_colonies medals);

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
    return WWW::LacunaExpanse::API::Connection->instance;
}

# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

#    $self->connection->debug(1);
    my $result = $self->connection->call($path, 'view_public_profile',[$self->connection->session_id, $self->id]);
#    $self->connection->debug(0);

    my $profile = $result->{result}{profile};

    # simple strings
    for my $attr (@simple_strings) {
        my $method = "_$attr";
        $self->$method($profile->{$attr});
    }

    # date strings
    for my $attr (@date_strings) {
        my $date = $profile->{$attr};
        my $method = "_$attr";
        $self->$method(WWW::LacunaExpanse::API::DateTime->from_lacuna_string($date));
    }

    # other strings
    my $alliance;
    if ($profile->{alliance}) {
        $alliance = WWW::LacunaExpanse::API::Alliance->new({
            id      => $profile->{alliance}{id},
            name    => $profile->{alliance}{name},
        });
    }
    $self->_alliance($alliance);

    # Colonies
    my @colonies;
    if ($profile->{known_colonies}) {
        for my $colony_hash (@{$profile->{known_colonies}}) {

            # Ore
            my $ores_hash = $colony_hash->{ore};
            my $ores;
            if ($ores_hash) {
                $ores = WWW::LacunaExpanse::API::Ores->new;
                for my $ore (qw(anthracite bauxite beryl chalcopyrite chromite flourite galena goethite
                    gold gypsum halite kerogen magnetite methane monazite rutile sulfur trona uraninite zircon)) {
                    $ores->$ore($ores_hash->{$ore});
                }
            }

            my $star = WWW::LacunaExpanse::API::Star->new({
                id      => $colony_hash->{star_id},
                name    => $colony_hash->{star_name},
            });

            my $known_colony = WWW::LacunaExpanse::API::Body->new({
                id      => $colony_hash->{id},
                name    => $colony_hash->{name},
                image   => $colony_hash->{image},
                orbit   => $colony_hash->{orbit},
                size    => $colony_hash->{size},
                type    => $colony_hash->{type},
                water   => $colony_hash->{water},
                x       => $colony_hash->{x},
                y       => $colony_hash->{y},
                ore     => $ores,
                empire  => $self,
                star    => $star,
            });
            push @colonies, $known_colony;
        }
    }
    $self->_known_colonies(\@colonies);


    $self->_medals('TBD');

}

# Find empire(s) by their name
#
sub find {
    my ($class, $empire_name) = @_;

    my $connection = WWW::LacunaExpanse::API::Connection->instance;

    my $result = $connection->call($path, 'find', [$connection->session_id, $empire_name]);

    my @ids = map {$_->{id}} @{$result->{result}{empires}};

    print "Search found the following IDs ".join('-', @ids)."\n";

    # create an Empire object for each ID found
    my $empires;
    for my $id (@ids) {
        my $empire = WWW::LacunaExpanse::API::Empire->new({id => $id});
        push @$empires, $empire;
    }
    return $empires;
}

1;
