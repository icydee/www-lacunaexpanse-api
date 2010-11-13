package WWW::LacunaExpanse::API::EmpireStats;

use Moose;
use Carp;

# Private attributes
has 'rpc'               => (is => 'ro', lazy_build => 1);
has 'cached'            => (is => 'ro');

my @simple_strings  = qw(colony_count population page_number
    empire_size building_count average_building_level offense_success_rate
    defense_success_rate dirtiest);
my @date_strings    = qw();
my @other_strings   = qw(empire alliance);

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

sub _build_rpc {
    my ($self) = @_;

    my $rpc = WWW::LacunaExpanse::API::RPC->instance;
    return $rpc;
}

# the full URI including the path
sub path {
    my ($self) = @_;
    return $self->rpc->uri.'/stats';
}

# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

    my $result = $self->rpc->call($self->path, 'empire_rank',[
        $self->rpc->session_id, $self->sort_by, $self->page_number]);

    $result = $result->{result};

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
    $self->empire('tbd');
    $self->alliance('tbd');
}

1;
