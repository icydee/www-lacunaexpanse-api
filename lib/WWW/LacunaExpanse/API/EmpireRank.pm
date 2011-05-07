package WWW::LacunaExpanse::API::EmpireRank;

use Moose;
use Carp;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'sort_by'           => (is => 'ro', default => 'empire_size_rank');
has 'page_number'       => (is => 'rw', default => 1);
has 'index'             => (is => 'rw', default => 0);
has 'cached'            => (is => 'ro', default => 0);

my $path = '/stats';

my @simple_strings  = qw(total_empires);
my @date_strings    = qw();
my @other_strings   = qw(empire_stats);

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

# Reset to the first record
#
sub reset_empire {
    my ($self) = @_;

    $self->index(0);
    $self->page_number(1);
}

# Return the next Empire in the Rank List
#
sub next_empire {
    my ($self) = @_;

    if ($self->index >= $self->total_empires) {
        return;
    }

    my $page_number = int($self->index / 25) + 1;
    if ($page_number != $self->page_number) {
        $self->page_number($page_number);
        $self->update;
    }
    my $empire_stat = $self->empire_stats->[$self->index % 25];
    $self->index($self->index + 1);
    return $empire_stat;
}

# Return the total number of empires
#
sub count_empires {
    my ($self) = @_;

    return $self->total_empires;
}


# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'empire_rank',[
        $self->connection->session_id, $self->sort_by, $self->page_number]);

    $self->connection->debug(0);

    $result = $result->{result};

    $self->simple_strings($result, \@simple_strings);

    $self->date_strings($result, \@date_strings);

    # other strings
    my @empire_stats;
    for my $empire_hash (@{$result->{empires}}) {
        my $empire = WWW::LacunaExpanse::API::Empire->new({
            id      => $empire_hash->{empire_id},
            name    => $empire_hash->{empire_name},
        });
        my $alliance = WWW::LacunaExpanse::API::Alliance->new({
            id      => $empire_hash->{alliance_id},
            name    => $empire_hash->{alliance_name},
        });

        my $empire_stat = WWW::LacunaExpanse::API::EmpireStats->new({
            empire                  => $empire,
            alliance                => $alliance,
            colony_count            => $empire_hash->{colony_count},
            population              => $empire_hash->{population},
            empire_size             => $empire_hash->{empire_size},
            building_count          => $empire_hash->{building_count},
            average_building_level  => $empire_hash->{average_building_level},
            offense_success_rate    => $empire_hash->{offense_success_rate},
            defense_success_rate    => $empire_hash->{defense_success_rate},
            dirtiest                => $empire_hash->{dirtiest},
        });

        push @empire_stats, $empire_stat;
    }
    $self->_empire_stats(\@empire_stats);
}

sub total_pages {
    my ($self) = @_;

    return int($self->total_empires / 25);
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
