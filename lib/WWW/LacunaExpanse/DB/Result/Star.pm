package WWW::LacunaExpanse::DB::Result::Star;

use strict;

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('star');
__PACKAGE__->add_columns(qw(
    server_id
    star_id
    name
    x
    y
    color
    sector
    )
);

__PACKAGE__->set_primary_key('server_id','star_id');

1;
