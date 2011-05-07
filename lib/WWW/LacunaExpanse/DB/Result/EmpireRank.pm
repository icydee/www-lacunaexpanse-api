package WWW::LacunaExpanse::DB::Result::EmpireRank;

use strict;

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(Core));
__PACKAGE__->table('empire_rank');
__PACKAGE__->add_columns(qw(
    server_id
    empire_id
    alliance_id
    on_date

    empire_name
    colony_count
    population
    empire_size
    building_count
    average_building_level
    offense_success_rate
    defense_success_rate
    dirtiest
    )
);

__PACKAGE__->set_primary_key('server_id','empire_id','alliance_id','on_date');

1;
