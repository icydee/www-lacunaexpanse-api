package WWW::LacunaExpanse::API::Building::GeneticsLab;

use Moose;
use Carp;
use Data::Dumper;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes

my @simple_strings  = qw(survival_odds graft_odds essentia_cost);
my @other_strings   = qw(grafts);

for my $attr (@simple_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->prepare_experiment;
            return $self->$attr;
        }
    );
}

# Stringify
use overload '""' => sub {
    my $gen = $_[0];

    my $str = "Genetics Lab\n";
    $str .= "  ID ..............: ".$gen->id."\n";
    $str .= "  Name ............: ".$gen->name."\n";
    $str .= "  Image ...........: ".$gen->image."\n";
    $str .= "  x ...............: ".$gen->x."\n";
    $str .= "  y ...............: ".$gen->y."\n";
    $str .= "  survival odds ...: ".$gen->survival_odds."\n";
    $str .= "  graft odds ......: ".$gen->graft_odds."\n";
    $str .= "  essentia cost ...: ".$gen->essentia_cost."\n";

    return $str;
};

# Refresh the Genetics Lab details
#
sub prepare_experiment {
    my ($self) = @_;

    $self->connection->debug(1);
    my $result = $self->connection->call($self->url, 'prepare_experiment',[
        $self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result};

    $self->simple_strings($body, \@simple_strings);

    # other strings
    my @grafts;
    for my $graft_hash (@{$body->{grafts}}) {
        my $spy_hash = $graft_hash->{spy};
        my $spy = WWW::LacunaExpanse::API::Spy->new({
            id                      => $spy_hash->{id},
            name                    => $spy_hash->{name},
            is_available            => $spy_hash->{is_available},
            level                   => $spy_hash->{level},
            mayhem                  => $spy_hash->{mayhem},
            politics                => $spy_hash->{politics},
            theft                   => $spy_hash->{theft},
            intel                   => $spy_hash->{intel},
            offense_rating          => $spy_hash->{offense_rating},
            defense_rating          => $spy_hash->{defense_rating},
            possible_assignments    => $spy_hash->{possible_assignments},
            seconds_remaining       => $spy_hash->{seconds_remaining},
            started_assignment      => $spy_hash->{started_assignment},
            available_on            => $spy_hash->{available_on},
            assignment              => $spy_hash->{assignment},
            assigned_to             => $spy_hash->{assigned_to},
        });

        my $species_hash = $graft_hash->{species};

        my $species = WWW::LacunaExpanse::API::Species->new({
            deception_affinity      => $species_hash->{deception_affinity},
            description             => $species_hash->{description},
            environmental_affinity  => $species_hash->{environmental_affinity},
            farming_affinity        => $species_hash->{farming_affinity},
            growth_affinity         => $species_hash->{growth_affinity},
            management_affinity     => $species_hash->{management_affinity},
            manufacturing_affinity  => $species_hash->{manufacturing_affinity},
            max_orbit               => $species_hash->{max_orbit},
            min_orbit               => $species_hash->{min_orbit},
            mining_affinity         => $species_hash->{mining_affinity},
            name                    => $species_hash->{name},
            political_affinity      => $species_hash->{political_affinity},
            research_affinity       => $species_hash->{research_affinity},
            science_affinity        => $species_hash->{science_affinity},
            trade_affinity          => $species_hash->{trade_affinity},
        });

        my $graft = WWW::LacunaExpanse::API::Graft->new({
            spy         => $spy,
            species     => $species,
            affinities  => $graft_hash->{graftable_affinities},
        });
        push @grafts, $graft;
    }

    $self->_grafts(\@grafts);
}

# Carry out the experiment
#
sub run_experiment {
    my ($self, $spy, $affinity) = @_;

    # Ensure the spy is here.
    my ($graft) = grep {$_->spy->id == $spy->id} @{$self->grafts};
    if (! $graft) {
        print "ERROR: spy '".$spy->name."' cannot be found\n";
        return;
    }

    # Ensure we are allowed to do this affinity
    my $check_affinity = grep {$_ eq $affinity} @{$graft->affinities};
    if (! $check_affinity) {
        print "ERROR: Affinity '".$affinity."' is not allowed for spy '".$spy->name."'\n";
        return;
    }

    print "Attempting to obtain affinity '".$affinity."' from spy '".$spy->name."'\n";

    $self->connection->debug(1);
    my $result = $self->connection->call($self->url, 'run_experiment',[
        $self->connection->session_id, $self->id, $spy->id, $affinity]);
    $self->connection->debug(0);

    return $result->{result}{experiment};
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
