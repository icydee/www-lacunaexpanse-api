package WWW::LacunaExpanse::API::Map::Star;

use Moose;
use Carp;
use WWW::LacunaExpanse::API::Bits::DateTime;

# This defines a single star

with 'WWW::LacunaExpanse::API::Role::Call';
with 'WWW::LacunaExpanse::API::Role::Attributes';

# Attributes based on the hash returned by the call
my $attributes = {
    id                      => 'Int',
    name                    => 'Str',
    color                   => 'Str',
    x                       => 'Int',
    y                       => 'Int',
    zone                    => 'Str',
    bodies                  => \'ArrayRef[WWW::LacunaExpanse::API::Body::Status]',
    station                 => \'WWW::LacunaExpanse::API::Body::Status',
};

# private: path to the URL to call
has '_path'  => (
    is          => 'ro',
    default     => '/map',
    init_arg    => undef,
);

has '_attributes' => (
    is          => 'ro',
    default     => sub {$attributes},
    init_arg    => undef,
);

create_attributes(__PACKAGE__, $attributes);

# Update by doing a call to get the objects status
#
sub update {
    my ($self) = @_;

    my $result = $self->call('get_star', {
        star_id     => $self->id,
    });
    $self->update_from_raw($result->{result}{star});
}


no Moose;
__PACKAGE__->meta->make_immutable;

