package WWW::LacunaExpanse::API;

use Moose;
use Data::Dump qw(dump);
use Carp;

use WWW::LacunaExpanse::API::MyEmpire;
use WWW::LacunaExpanse::API::Empire;
use WWW::LacunaExpanse::API::EmpireRank;
use WWW::LacunaExpanse::API::Connection;
use WWW::LacunaExpanse::API::Body;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::API::Alliance;
use WWW::LacunaExpanse::API::EmpireStats;

# This is the base class for the API

# Private attributes
has 'uri'           => (is => 'ro', required => 1);
has 'username'      => (is => 'ro', required => 1);
has 'password'      => (is => 'ro', required => 1);
has 'my_empire'     => (is => 'ro', lazy_build => 1);
has 'connection'    => (is => 'ro', lazy_build => 1);

my $status;

# Do an auto-login and get the initial status
sub BUILD {
    my ($self) = @_;

    WWW::LacunaExpanse::API::Connection->initialize({
        uri         => $self->uri,
        username    => $self->username,
        password    => $self->password,
    });

}

# Lazy build of connection
#
sub _build_connection {
    my ($self) = @_;

    return WWW::LacunaExpanse::API::Connection->instance;
}

# Lazy build of My Empire
#
sub _build_my_empire {
    my ($self) = @_;

    my $my_empire = WWW::LacunaExpanse::API::MyEmpire->new({
    });
    return $my_empire;
}

# Generic Find method
#
sub find {
    my ($self, $args) = @_;

    if ($args->{empire}) {
        print "search for empire [".$args->{empire}."]\n";
        return WWW::LacunaExpanse::API::Empire->find($args->{empire});
    }

}

sub empire_rank {
    my ($self, $args) = @_;

    my $empire_rank = WWW::LacunaExpanse::API::EmpireRank->new($args);

    return $empire_rank
}



1;
