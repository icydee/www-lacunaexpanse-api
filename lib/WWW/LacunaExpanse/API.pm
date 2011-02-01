package WWW::LacunaExpanse::API;

use Moose;
use Data::Dumper;
use Carp;
use Contextual::Return;

use WWW::LacunaExpanse::API::MyEmpire;
use WWW::LacunaExpanse::API::Cost;
use WWW::LacunaExpanse::API::VirtualShip;
use WWW::LacunaExpanse::API::Ship;
use WWW::LacunaExpanse::API::Empire;
use WWW::LacunaExpanse::API::EmpireRank;
use WWW::LacunaExpanse::API::Connection;
use WWW::LacunaExpanse::API::Body;
use WWW::LacunaExpanse::API::Colony;
use WWW::LacunaExpanse::API::MyColony;
use WWW::LacunaExpanse::API::Graft;
use WWW::LacunaExpanse::API::Inbox;
use WWW::LacunaExpanse::API::Spy;
use WWW::LacunaExpanse::API::Species;
use WWW::LacunaExpanse::API::Star;
use WWW::LacunaExpanse::API::Ore;
use WWW::LacunaExpanse::API::Ores;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::API::Alliance;
use WWW::LacunaExpanse::API::EmpireStats;
use WWW::LacunaExpanse::API::BuildingFactory;
use WWW::LacunaExpanse::API::Building::Timer;
use WWW::LacunaExpanse::API::Building::Generic;
use WWW::LacunaExpanse::API::Building::SpacePort;
use WWW::LacunaExpanse::API::Building::GeneticsLab;
use WWW::LacunaExpanse::API::Building::TradeMinistry;
use WWW::LacunaExpanse::API::Building::ArchaeologyMinistry;
use WWW::LacunaExpanse::API::Building::PlanetaryCommandCenter;

# This is the base class for the API

# Attributes
has 'uri'           => (is => 'ro', required => 1);
has 'username'      => (is => 'rw', required => 0);
has 'password'      => (is => 'rw', required => 0);
has 'debug_hits'    => (is => 'rw', default => 0);
has 'my_empire'     => (is => 'ro', lazy_build => 1);
has 'inbox'         => (is => 'ro', lazy_build => 1);
has 'connection'    => (is => 'ro', lazy_build => 1);

my $status;

# Do an auto-login and get the initial status
sub BUILD {
    my ($self) = @_;

    WWW::LacunaExpanse::API::Connection->initialize({
        uri         => $self->uri,
        username    => $self->username,
        password    => $self->password,
        debug_hits  => $self->debug_hits,
    });
}

# Lazy build of connection
#
sub _build_connection {
    my ($self) = @_;

    return WWW::LacunaExpanse::API::Connection->instance;
}

# Lazy build of Inbox
#
sub _build_inbox {
    my ($self) = @_;

    my $inbox = WWW::LacunaExpanse::API::Inbox->new({
    });

    return $inbox;
}

# Lazy build of My Empire
#
sub _build_my_empire {
    my ($self) = @_;

    my $my_empire = {};

    if ($self->connection->session_id) {
        $self->connection->debug(0);
        my $result = $self->connection->call('/empire', 'get_status',[$self->connection->session_id]);
        $self->connection->debug(0);

        my $data = $result->{result}{empire};

        $my_empire = WWW::LacunaExpanse::API::MyEmpire->new({
            id      => $data->{id},
            name    => $data->{name},
        });
    }

    return $my_empire;
}

# Generic Find method
#
sub find {
    my ($self, $args) = @_;

    my $things;
    if ($args->{empire}) {
#        print "search for empire [".$args->{empire}."]\n";
        $things = WWW::LacunaExpanse::API::Empire->find($args->{empire});
    }

    if ($args->{star}) {
#        print "search for star [".$args->{star}."]\n";
        $things = WWW::LacunaExpanse::API::Star->find($args->{star});
    }

    if ($args->{my_colony}) {
#        print "search for my colony [".$args->{my_colony}."]\n";
        $things = $self->my_empire->find_colony($args->{my_colony});
    }

    return (
        LIST        { @$things;         }
        SCALAR      { $things->[0];    }
    );
}

sub empire_rank {
    my ($self, $args) = @_;

    my $empire_rank = WWW::LacunaExpanse::API::EmpireRank->new($args);

    return $empire_rank
}

sub is_name_available {
    my ($self, $name) = @_;
    local $@;

    my $result = eval { $self->connection->call('/empire', 'is_name_available', [$name]) };

    return $@ ? 0 : $result->{result};
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
