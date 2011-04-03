package WWW::LacunaExpanse::DB::Result::Body;

use strict;

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('body');
__PACKAGE__->add_columns(qw(
    server_id
    body_id
    orbit
    name
    x
    y
    image
    size
    type
    star_id
    empire_id
    water
    )
);

__PACKAGE__->set_primary_key('server_id','body_id');

1;
