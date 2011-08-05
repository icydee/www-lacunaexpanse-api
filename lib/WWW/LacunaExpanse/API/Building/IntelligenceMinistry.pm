package WWW::LacunaExpanse::API::Building::IntelligenceMinistry;

use Moose;
use Carp;
use Data::Dumper;

extends 'WWW::LacunaExpanse::API::Building::Generic';

# Attributes

my @simple_strings  = qw(maximum current in_training);
my @date_strings    = qw();
my @other_strings   = qw();

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->view;
            return $self->$attr;
        }
    );
}

sub view {
    my ($self) = @_;

    my $result = $self->connection->call($self->url, 'view', [$self->connection->session_id, $self->id]);

    my $body = $result->{result}{spies};

    $self->simple_strings($body, \@simple_strings);
    $self->date_strings($body, \@date_strings);

    # other strings
}


sub train_spy {
    my ($self, $quantity) = @_;

    my $result = $self->connection->call($self->url, 'train_spy', [$self->connection->session_id, $self->id, $quantity]);

    my $body = $result->{result};

    return $body->{trained};
}


sub all_spies {
    my ($self) = @_;

    my @all_spies;
    my $page_number = 1;
    while ($page_number <= int( ($self->current - 1) / 25) + 1) {
        my $result = $self->connection->call($self->url, 'view_spies', [$self->connection->session_id, $self->id, $page_number]);
        my $body = $result->{result}{spies};

        for my $spy_hash (@$body) {
            my $spy = WWW::LacunaExpanse::API::Spy->new({
                id                  => $spy_hash->{id},
                name                => $spy_hash->{name},
                is_available        => $spy_hash->{is_available},
                level               => $spy_hash->{level},
                mayhem              => $spy_hash->{mayhem},
                politics            => $spy_hash->{politics},
                theft               => $spy_hash->{theft},
                intel               => $spy_hash->{intel},
                offense_rating      => $spy_hash->{offense_rating},
                defense_rating      => $spy_hash->{defense_rating},
            });
            push @all_spies, $spy;
        }
        $page_number++;
    }
    return \@all_spies;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
