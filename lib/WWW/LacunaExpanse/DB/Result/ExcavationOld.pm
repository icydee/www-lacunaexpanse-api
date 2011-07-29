package WWW::LacunaExpanse::DB::Result::ExcavationOld;

use strict;

use base qw(DBIx::Class);

use DateTime::Format::MySQL;

__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('excavation_old');
__PACKAGE__->add_columns(qw(
    server_id
    empire_id
    body_id
    on_date
    colony_id
    resource_genre
    resource_type
    resource_qty
    )
);

__PACKAGE__->set_primary_key('server_id','empire_id','body_id','on_date');

__PACKAGE__->inflate_column('on_date', {
    inflate => sub { DateTime::Format::MySQL->parse_datetime(shift); },
    deflate => sub { DateTime::Format::MySQL->format_datetime(shift); },
    }
);

1;
