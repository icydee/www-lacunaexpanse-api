package WWW::LacunaExpanse::DB::Result::AllianceStat;

use strict;

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(Core));
__PACKAGE__->table('alliance_stat');
__PACKAGE__->add_columns(qw(
    server_id
    alliance_id
    on_date

    alliance_name
    )
);

__PACKAGE__->set_primary_key('server_id','alliance_id','on_date');

1;
