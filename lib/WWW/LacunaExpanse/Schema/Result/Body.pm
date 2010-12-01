package WWW::LacunaExpanse::Schema::Result::Body;

use Modern::Perl;

use base 'DBIx::Class';

__PACKAGE__->load_components('PK::Auto','Core');
__PACKAGE__->table("body");

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
    image => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    size => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    type => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    star_id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    empire_id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 1,
        size            => 10,
    },
    water => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
);
__PACKAGE__->set_primary_key("id");

# Every Body has a Star
__PACKAGE__->belongs_to(
  "star",
  "WWW::LacunaExpanse::Schema::Star",
  { id => "star_id" },
);

# A body may have many ores
__PACKAGE__->has_many(
  "ores",
  "WWW::LacunaExpanse::Schema::Ore",
  { "foreign.body_id" => "self.id" },
);

1;
