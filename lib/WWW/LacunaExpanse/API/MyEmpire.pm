package WWW::LacunaExpanse::API::MyEmpire;

use Moose;
use Carp;

extends 'WWW::LacunaExpanse::API::Empire';

my $path = '/empire';

my @simple_strings  = qw(is_isolationist name status_message has_new_messages essentia self_destruct_active);
my @date_strings    = qw(self_destruct_date);
my @other_strings   = qw(home_planet most_recent_message colonies);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->update_my_empire;
            return $self->$attr;
        }
    );
}

# Find out what the limits are on redefining the species
#
sub redefine_species_limits {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'redefine_species_limits',[$self->connection->session_id]);
    $self->connection->debug(0);

}

# Redefine our species
#
sub redefine_species {
    my ($self, $params) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'redefine_species',[$self->connection->session_id, $params]);
    $self->connection->debug(0);

}


sub update_my_empire {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'get_status',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result}{empire};

    $self->simple_strings($body, \@simple_strings);

    $self->date_strings($body, \@date_strings);

    my $home_planet = WWW::LacunaExpanse::API::MyColony->new({
        id  => $body->{home_planet_id},
    });
    $self->_home_planet($home_planet);

    my $most_recent_message;
    if ($body->{most_recent_message}) {
        # TBD
    }
    $self->_most_recent_message($most_recent_message);

    my @my_colonies;
    for my $planet_id (keys %{$body->{planets}}) {
        my $colony = WWW::LacunaExpanse::API::MyColony->new({
            id      => $planet_id,
            name    => $body->{planets}{$planet_id},
        });
        push @my_colonies, $colony;
    }

    $self->_colonies(\@my_colonies);
}

# Find a colony by it's name
#
sub find_colony {
    my ($self, $name) = @_;

    my @colonies;
    for my $colony (@{$self->colonies}) {
#        print "Testing colony name [".$colony->name."] against [$name]\n";
        if ($colony->name =~ m/^$name/i) {
            push @colonies, $colony;
        }
    }
    return \@colonies;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
