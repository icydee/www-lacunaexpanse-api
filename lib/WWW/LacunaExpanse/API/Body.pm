package WWW::LacunaExpanse::API::Body;

use Moose;
use Carp;

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'connection'        => (is => 'ro', lazy_build => 1);
has 'cached'            => (is => 'ro');

my $path = '/empire';

my @simple_strings  = qw(image name orbit size type water x y);
my @date_strings    = qw();
my @other_strings   = qw(ore star empire);

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

    $self->connection->debug(1);
    my $result = $self->connection->call($path, 'get_status',[$self->connection->session_id, $self->id]);
    $self->connection->debug(1);

    $result = $result->{body};

    # simple strings
    for my $attr (@simple_strings) {
        my $method = "_$attr";
        $self->$method($result->{$attr});
    }

    # date strings
    for my $attr (@date_strings) {
        my $date = $result->{$attr};
        my $method = "_$attr";
        $self->$method(WWW::LacunaExpanse::API::DateTime->from_lacuna_string($date));
    }

    # other strings
    # Ore
    my $ores_hash = $result->{body}{ore};
    my $ores;
    if ($ores_hash) {
        $ores = WWW::LacunaExpanse::API::Ores->new;
        for my $ore (qw(anthracite bauxite beryl chalcopyrite chromite flourite galena goethite
            gold gypsum halite kerogen magnetite methane monazite rutile sulfur trona uraninite zircon)) {
            $ores->$ore($ores_hash->{$ore});
        }
    }

    $self->ore($ores);
print "### Body.pm: creating a star ###\n";
    my $star = WWW::LacunaExpanse::API::Star->new({
        id      => $result->{star}{id},
        name    => $result->{star}{name},
    });
    $self->star($star);

    $self->empire('TBD');
}

1;
