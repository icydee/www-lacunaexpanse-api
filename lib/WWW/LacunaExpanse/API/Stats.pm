package WWW::LacunaExpanse::API::Stats;

use Moose;
use Carp;
use DateTime;
use Data::Dumper;

use WWW::LacunaExpanse::API::Message;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'empire_ranks' => (is => 'rw', lazy => 1, builder => '_build_empire_ranks');

sub _build_empire_ranks {
    my ($self) = @_;

    my $log = Log::Log4perl->get_logger('WWW::LacunaExpanse::API::Stats');

    my $page_number = 1;
    my @empires;
    PAGE:
    while (1) {
        my $result = $self->connection->call('/stats', 'empire_rank',[
            $self->connection->session_id,
            'empire_size_rank',
            $page_number,
        ]);

        $result = $result->{result};

        my $empire_found = 0;
        for my $empire_hash (@{$result->{empires}}) {
            $empire_found++;

            my $empire = WWW::LacunaExpanse::API::Empire->new({
                id      => $empire_hash->{empire_id},
                name    => $empire_hash->{empire_name},
            });
            my $alliance_stat = WWW::LacunaExpanse::API::AllianceStat->new({
                alliance_id     => $empire_hash->{alliance_id},
                alliance_name   => $empire_hash->{alliance_name},
            });

            my $now = DateTime->now;
            my $empire_stat = WWW::LacunaExpanse::API::EmpireStats->new({
                empire                  => $empire,
                alliance_stat           => $alliance_stat,
                colony_count            => $empire_hash->{colony_count},
                population              => $empire_hash->{population},
                empire_size             => $empire_hash->{empire_size},
                building_count          => $empire_hash->{building_count},
                average_building_level  => $empire_hash->{average_building_level},
                offense_success_rate    => $empire_hash->{offense_success_rate},
                defense_success_rate    => $empire_hash->{defense_success_rate},
                dirtiest                => $empire_hash->{dirtiest},
            });

            push @empires, $empire_stat;
        }
        $log->debug("There were $empire_found empires found");
        last PAGE unless $empire_found;
        $page_number++;

#        last PAGE if $page_number == 5;
    }
    return \@empires;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
