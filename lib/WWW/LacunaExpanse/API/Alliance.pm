package WWW::LacunaExpanse::API::Alliance;

use Moose;
use Carp;

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'rpc'               => (is => 'ro', lazy_build => 1);
has 'cached'            => (is => 'ro');

my @simple_strings  = qw(name description influence);
my @date_strings    = qw(date_created);
my @other_strings   = qw(leader members space_stations);

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

    my $rpc = WWW::LacunaExpanse::API::Connection->instance;
    return $rpc;
}

# the full URI including the path
sub path {
    my ($self) = @_;
    return $self->connection->uri.'/alliance';
}

# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

    my $result = $self->connection->call($self->path, 'view_profile',[$self->connection->session_id, $self->id]);

    my $profile = $result->{result}{profile};

    # simple strings
    for my $attr (@simple_strings) {
        my $method = "_$attr";
        $self->$method($profile->{$attr});
    }

    # date strings
    for my $attr (@date_strings) {
        my $date = $profile->{$attr};
        my $method = "_$attr";
        $self->$method(WWW::LacunaExpanse::API::DateTime->from_lacuna_string($date));
    }

    $self->_leader(WWW::LacunaExpanse::API::Empire->new({
        id      => $profile->{leader_id},
    }));

    my @members;
    for my $member_hash (@{$profile->{members}}) {
        my $member = WWW::LacunaExpanse::API::Empire->new({
            id      => $member_hash->{id},
            name    => $member_hash->{name},
        });
        push @members, $member;
    }
    $self->_members(\@members);

    $self->_space_stations('TBD');

}

1;
