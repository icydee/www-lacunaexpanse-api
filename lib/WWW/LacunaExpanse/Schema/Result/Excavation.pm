package WWW::LacunaExpanse::Schema::Result::Excavation;

use Modern::Perl;

use base 'DBIx::Class';

__PACKAGE__->load_components('PK::Auto','Core');
__PACKAGE__->table("excavation");

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
    on_date => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    resource_genre => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    resource_type => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
    resource_qty => {
        data_type       => "TEXT",
        default_value   => undef,
        is_nullable     => 0,
        size            => 10,
    },
);
__PACKAGE__->set_primary_key("id");

# Every Excavation takes place on a body
__PACKAGE__->belongs_to(
  "body",
  "WWW::LacunaExpanse::Schema::Result::Body",
  { id => "body_id" },
);

1;
