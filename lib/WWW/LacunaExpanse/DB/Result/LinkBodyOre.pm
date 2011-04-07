package WWW::LacunaExpanse::DB::Result::LinkBodyOre;

use strict;

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('link_body__ore');
__PACKAGE__->add_columns(qw(
    server_id
    body_id
    ore_id
    quantity
    )
);

__PACKAGE__->set_primary_key('server_id','body_id','ore_id');

1;
