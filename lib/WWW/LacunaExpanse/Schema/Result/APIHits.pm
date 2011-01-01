package WWW::LacunaExpanse::Schema::Result::APIHits;

use Modern::Perl;

use base 'DBIx::Class';

__PACKAGE__->load_components('PK::Auto','Core');
__PACKAGE__->table("api_hits");

__PACKAGE__->add_columns(
    id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    script => {
        data_type       => "TEXT",
        default_value   => "",
        is_nullable     => 0,
        size            => 10,
    },
    on_date => {
        data_type       => "TEXT",
        default_value   => "",
        is_nullable     => 0,
        size            => 10,
    },
    hits => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
);
__PACKAGE__->set_primary_key("id");

1;
