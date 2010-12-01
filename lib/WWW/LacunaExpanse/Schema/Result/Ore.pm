package WWW::LacunaExpanse::Schema::Result::Ore;

use Modern::Perl;

use base 'DBIx::Class';

__PACKAGE__->load_components('PK::Auto','Core');
__PACKAGE__->table("ore");

__PACKAGE__->add_columns(
    id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    name => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
);
__PACKAGE__->set_primary_key("id");

# Every Ore has many LinkBodyOres
__PACKAGE__->belongs_to(
  "link_body_ores",
  "WWW::LacunaExpanse::Schema::LinkBodyOre",
  { id => "ore_id" },
);

1;
