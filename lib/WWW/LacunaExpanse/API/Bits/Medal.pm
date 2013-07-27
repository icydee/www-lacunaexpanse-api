package WWW::LacunaExpanse::API::Bits::Medal;

use Moose;
use Carp;

with 'WWW::LacunaExpanse::API::Role::Attributes';

my $attributes = {
    id              => 'Int',
    name            => 'Str',
    image           => 'Str',
    date            => \'WWW::LacunaExpanse::API::Bits::DateTime',
    public          => 'Int',
    times_earned    => 'Int',
};

has '_attributes' => (
    is          => 'ro',
    default     => sub {$attributes},
    init_arg    => undef,
);

create_attributes(__PACKAGE__, $attributes);

no Moose;
__PACKAGE__->meta->make_immutable;
1;
