package WWW::LacunaExpanse::API::Empire::OwnProfile;

use Moose;
use Carp;
use WWW::LacunaExpanse::API::Bits::DateTime;
use WWW::LacunaExpanse::API::Body::Status;

with 'WWW::LacunaExpanse::API::Role::Connection';
with 'WWW::LacunaExpanse::API::Role::Attributes';

# Attributes based on the hash returned by the call
my $attributes = {
    id                      => 'Int',
    player_name             => 'Maybe[Str]',
    description             => 'Maybe[Str]',
    status_message          => 'Maybe[Str]',
    city                    => 'Maybe[Str]',
    country                 => 'Maybe[Str]',
    notes                   => 'Maybe[Str]',
    skype                   => 'Maybe[Str]',
    player_name             => 'Maybe[Str]',
    email                   => 'Maybe[Str]',
    sitter_password         => 'Str',
    medals                  => \'ArrayRef[WWW::LacunaExpanse::API::Bits::Medal]',
};

# private: path to the URL to call
has '_path'  => (
    is          => 'ro',
    default     => '/empire',
    init_arg    => undef,
);

has '_attributes' => (
    is          => 'ro',
    default     => sub {$attributes},
    init_arg    => undef,
);

create_attributes(__PACKAGE__, $attributes);

sub update {
    my ($self) = @_;
    my $result = $self->connection->call($self->_path, 'get_own_profile',[{
        session_id  => $self->connection->session_id,
    }]);
    $self->update_from_raw($result->{result}{own_profile});
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
