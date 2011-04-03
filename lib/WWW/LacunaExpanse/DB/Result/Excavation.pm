package WWW::LacunaExpanse::DB::Result::Excavation;

use strict;

use base qw(DBIx::Class);

use DateTime::Format::MySQL;

__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('excavation');

__PACKAGE__->add_columns( id => {is_auto_increment => 1} );

__PACKAGE__->add_columns(qw(
    server_id
    empire_id
    body_id
    body_name
    on_date
    colony_id
    resource_genre
    resource_type
    resource_qty
    )
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->inflate_column('on_date', {
    inflate => sub { DateTime::Format::MySQL->parse_datetime(shift); },
    deflate => sub { DateTime::Format::MySQL->format_datetime(shift); },
    }
);

1;
