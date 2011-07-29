package WWW::LacunaExpanse::DB::Result::Glyph;

use strict;

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(PK::Auto Core));
__PACKAGE__->table('glyph');
__PACKAGE__->add_columns(qw(
    server_id
    empire_id
    glyph_id
    glyph_type
    found_on
    )
);

__PACKAGE__->set_primary_key('server_id','empire_id','glyph_id');

1;
