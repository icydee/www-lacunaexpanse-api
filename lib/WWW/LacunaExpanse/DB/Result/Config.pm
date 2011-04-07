package WWW::LacunaExpanse::DB::Result::Config;

use strict;

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('config');
__PACKAGE__->add_columns(qw(
    server_id
    empire_id
    name
    val
    )
);

__PACKAGE__->set_primary_key('server_id','empire_id','name');

1;
