package WWW::LacunaExpanse::API;

use Moose;
use Data::Dumper;
use Carp;
use Contextual::Return;

use WWW::LacunaExpanse::API::Empire;

with 'WWW::LacunaExpanse::API::Role::Call';

# This is the base class for the API

# Attributes
has 'uri'           => (is => 'ro', required => 1);
has 'username'      => (is => 'rw', required => 0);
has 'password'      => (is => 'rw', required => 0);
has 'debug_hits'    => (is => 'rw', default => 0);
has 'empire'        => (is => 'ro', lazy_build => 1);
has 'map'           => (is => 'ro', lazy_build => 1);
has 'inbox'         => (is => 'ro', lazy_build => 1);

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
sub _build_empire {
    my ($self) = @_;

    my $empire;

    if ($self->connection->session_id) {
        my $result = $self->connection->call('/empire', 'get_status',[{ session_id => $self->connection->session_id}]);

        my $data = $result->{result}{empire};

        $empire = WWW::LacunaExpanse::API::Empire->new({
            id      => $data->{id},
            name    => $data->{name},
            connection  => $self->connection,
        });
    }

    return $empire;
}

# Lazy build of Map
#
sub _build_map {
    my ($self) = @_;

    my $map = WWW::LacunaExpanse::API::Map->new({
        connectio => $self->connection,
    });
    return $map;
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
        $things = $self->empire->find_colony($args->{my_colony});
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

    my $result = eval { return $self->connection->call('/empire', 'is_name_available', [$name]) };

    return $@ ? 0 : $result->{result};
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
