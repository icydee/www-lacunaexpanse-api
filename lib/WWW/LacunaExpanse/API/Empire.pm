package WWW::LacunaExpanse::API::Empire;

use Moose;
use Carp;
use WWW::LacunaExpanse::API::Empire::Status;

# This defines your own Empire and all the attributes and methods that go with it
# mostly, this is obtained by a call to /empire get_status

with 'WWW::LacunaExpanse::API::Role::Connection';

has 'id'        => (
    is          => 'ro',
    isa         => 'Int',
    required    => 1,
);

has 'path'      => (
    is          => 'ro',
    default     => '/empire',
);
has 'status'    => (
    is          => 'rw',
    isa         => 'WWW::LacunaExpanse::API::Empire::Status',
    lazy        => 1,
    builder     => '_build_status',
);

sub _build_status {
    my ($self) = @_;
    my $result = $self->connection->call($self->path, 'get_status',[{
        session_id  => $self->connection->session_id, 
    }]);
    my $body = $result->{result}{empire};
    return WWW::LacunaExpanse::API::Empire::Status->new_from_raw($body);
    
}

extends 'WWW::LacunaExpanse::API';

no Moose;
__PACKAGE__->meta->make_immutable;
1;
