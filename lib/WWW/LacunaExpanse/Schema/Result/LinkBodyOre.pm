package WWW::LacunaExpanse::Schema::Result::LinkBodyOre;

use Modern::Perl;

use base 'DBIx::Class';

__PACKAGE__->load_components('PK::Auto','Core');
__PACKAGE__->table("link_body__ore");

__PACKAGE__->add_columns(
    id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    body_id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    ore_id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    quantity => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
);
__PACKAGE__->set_primary_key("id");

# Every LinkBodyOre has a Body
__PACKAGE__->belongs_to(
  "body",
  "WWW::LacunaExpanse::Schema::Body",
  { id => "body_id" },
);

# Every LinkBodyOre has an Ore
__PACKAGE__->belongs_to(
  "ore",
  "WWW::LacunaExpanse::Schema::Ore",
  { id => "ore_id" },
);


1;
