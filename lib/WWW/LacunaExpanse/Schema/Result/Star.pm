package WWW::LacunaExpanse::Schema::Result::Star;

use Modern::Perl;

use base 'DBIx::Class';

__PACKAGE__->load_components('PK::Auto','Core');
__PACKAGE__->table("star");

__PACKAGE__->add_columns(
    id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    name => {
        data_type       => "TEXT",
        default_value   => "",
        is_nullable     => 0,
        size            => 10,
    },
    x => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    y => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    color => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    sector => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    scan_date => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 1,
        size            => 10,
    },
    empire_id => {
        data_type       => "INTEGER",
        default_value   => undef,
        is_nullable     => 1,
        size            => 10,
    },
    status => {
        data_type       => "INTEGER",
        default_value   => undef,
        is_nullable     => 1,
        size            => 10,
    },
);
__PACKAGE__->set_primary_key("id");

# A star may have many bodies
__PACKAGE__->has_many(
  "bodies",
  "WWW::LacunaExpanse::Schema::Result::Body",
  { "foreign.star_id" => "self.id" },
);

1;
