package WWW::LacunaExpanse::API::Empire;

use Moose;
use Carp;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'cached'            => (is => 'ro');

my $path = '/empire';

my @simple_strings  = qw(description name city country colony_count player_name skype species status_message);
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

# Stringify
use overload '""' => sub {
    my $empire = $_[0];
    my $str = "Empire\n";
    $str .= "  ID               : ".$empire->id."\n";
    $str .= "  name             : ".$empire->name."\n";
    $str .= "  description      : ".$empire->description."\n";
    $str .= "  city             : ".$empire->city."\n";
    $str .= "  country          : ".$empire->country."\n";
    $str .= "  colony_count     : ".$empire->colony_count."\n";
    $str .= "  player_name      : ".$empire->player_name."\n";
    $str .= "  skype            : ".$empire->skype."\n";
    $str .= "  species          : ".$empire->species."\n";
    $str .= "  status message   : ".$empire->status_message."\n";
    $str .= "  date founded     : ".$empire->date_founded."\n";
    $str .= "  last login       : ".$empire->last_login."\n";
    if ($empire->alliance) {
        $str .= "  alliance         : ".$empire->alliance->name."\n";
    }
    for my $colony (@{$empire->known_colonies}) {
        $str .= $colony;
    }
#    for my $medal (@{$empire->medals}) {
#        $str .= $medal;
#    }

    return $str;
};

# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'view_public_profile',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $profile = $result->{result}{profile};

    $self->simple_strings($profile, \@simple_strings);

    $self->date_strings($profile, \@date_strings);

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
    my @known_colonies;
    if ($profile->{known_colonies}) {
        for my $colony_hash (@{$profile->{known_colonies}}) {

#            # Ore
#            my $ores_hash = $colony_hash->{ore};
#            my $ores;
#            if ($ores_hash) {
#                $ores = WWW::LacunaExpanse::API::Ores->new;
#                for my $ore (qw(anthracite bauxite beryl chalcopyrite chromite flourite galena goethite
#                    gold gypsum halite kerogen magnetite methane monazite rutile sulfur trona uraninite zircon)) {
#                    $ores->$ore($ores_hash->{$ore});
#                }
#            }
#
#            my $star = WWW::LacunaExpanse::API::Star->new({
#                id      => $colony_hash->{star_id},
#                name    => $colony_hash->{star_name},
#            });

#            # If we own the planet then 'building_count' will be present
#            # in which case make it a 'Colony' object, otherwise a 'Body'
#            my $obj;
#
#            if ($colony_hash->{building_count}) {
#                $obj = WWW::LacunaExpanse::API::Colony->new({
#                    id  => $colony_hash->{id},
#                });
#            }
#            else {
#                $obj = WWW::LacunaExpanse::API::Body->new({
#                    id  => $colony_hash->{id},
#                });
#            }
#
#            for my $str (qw(name image orbit size type water x y)) {
#                my $attr = "_$str";
#                $obj->$attr($colony_hash->{$str});
#            }

            my $colony = WWW::LacunaExpanse::API::Colony->new({
                id      => $colony_hash->{id},
                x       => $colony_hash->{x},
                y       => $colony_hash->{y},
                name    => $colony_hash->{name},
                image   => $colony_hash->{image},
            });
#            $colony->_ore($ores);
            $colony->_empire($self);
#            $colony->_star($star);

#            if ($colony_hash->{building_count}) {
#                for my $str (qw(needs_surface_refresh building_count plots_available happiness
#                    happiness_hour food_stored food_capacity food_hour energy_stored energy_capacity
#                    energy_hour ore_stored ore_capacity ore_hour waste_stored waste_capacity waste hour
#                    water_stored water_capacity water_hour)) {
#                    $body->$str($colony_hash->{$str});
#                }
#
#                my $incoming_foreign_ships;
#                if ($colony_hash->{incoming_foreign_ships}) {
#                }
#                $body->incoming_foreign_ships('TBD');
#            }

            push @known_colonies, $colony;
        }
    }
    $self->_known_colonies(\@known_colonies);


    $self->_medals('TBD');

}

# Find empire(s) by their name
#
sub find {
    my ($class, $empire_name) = @_;

    my $connection = WWW::LacunaExpanse::API::Connection->instance;

    my $result = $connection->call($path, 'find', [$connection->session_id, $empire_name]);

    my @ids = map {$_->{id}} @{$result->{result}{empires}};

#    print "Search found the following IDs ".join('-', @ids)."\n";

    # create an Empire object for each ID found
    my $empires;
    for my $id (@ids) {
        my $empire = WWW::LacunaExpanse::API::Empire->new({id => $id});
        push @$empires, $empire;
    }
    return $empires;
}


# Return the rank information for an empire
#
sub rank {
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
