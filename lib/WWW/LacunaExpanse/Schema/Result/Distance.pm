package WWW::LacunaExpanse::Schema::Result::Distance;

use Modern::Perl;

use base 'DBIx::Class';

__PACKAGE__->load_components('PK::Auto','Core');
__PACKAGE__->table("distance");

__PACKAGE__->add_columns(
    id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    from_id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    to_id => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    distance => {
        data_type       => "INT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
);
__PACKAGE__->set_primary_key("id");

# Every Distance has a From Body
__PACKAGE__->belongs_to(
  "from_body",
  "WWW::LacunaExpanse::Schema::Result::Body",
  { id => "from_id" },
);

# Every Distance has a To Body
__PACKAGE__->belongs_to(
  "to_star",
  "WWW::LacunaExpanse::Schema::Result::Star",
  { id => "to_id" },
);

1;
