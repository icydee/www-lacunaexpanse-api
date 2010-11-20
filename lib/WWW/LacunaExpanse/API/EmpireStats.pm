package WWW::LacunaExpanse::API::EmpireStats;

use Moose;
use Carp;

my @simple_strings  = qw(colony_count population
    empire_size building_count average_building_level offense_success_rate
    defense_success_rate dirtiest);
my @date_strings    = qw();
my @other_strings   = qw(empire alliance);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', required => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->update;
            return $self->$attr;
        }
    );
}


1;
