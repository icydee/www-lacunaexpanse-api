package WWW::LacunaExpanse::API::Building::Generic;

use Moose;
use Carp;
use Data::Dumper;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'url'               => (is => 'ro', required => 1);

my @simple_strings  = qw(name x y image level efficiency food_hour food_capacity energy_hour
    energy_capacity ore_hour ore_capacity water_hour water_capacity waste_hour waste_capacity
    energy_hour energy_capacity food_hour food_capacity happiness_hour);
my @date_strings    = qw();
my @other_strings   = qw(repair_costs pending_build work upgrade);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
print "generic accessing --- $attr\n";
            my ($self) = @_;
            $self->update;
            return $self->$attr;
        }
    );
}


# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

print "### calling generic update ###\n";

    $self->connection->debug(0);
    my $result = $self->connection->call($self->url, 'view',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $body = $result->{result}{building};

    $self->simple_strings($body, \@simple_strings);

    $self->date_strings($body, \@date_strings);

    # other strings
    $self->_pending_build('TBD');
    $self->_work('TBD');
    $self->_upgrade('TBD');
    $self->_repair_costs('TBD');
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
