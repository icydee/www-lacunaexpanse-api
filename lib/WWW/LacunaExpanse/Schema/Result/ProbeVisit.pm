package WWW::LacunaExpanse::Schema::Result::ProbeVisit;

use Modern::Perl;

use base 'DBIx::Class';

__PACKAGE__->load_components('PK::Auto','Core');
__PACKAGE__->table("probe_visit");

__PACKAGE__->add_columns(
    id => {
        data_type       => "INT",
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
    on_date => {
        data_type       => "TEXT",
        default_value   => "",
        is_nullable     => 0,
        size            => 10,
    },
);
__PACKAGE__->set_primary_key("id");

# Every Body has a Star
__PACKAGE__->belongs_to(
  "star",
  "WWW::LacunaExpanse::Schema::Result::Star",
  { id => "star_id" },
);

1;
