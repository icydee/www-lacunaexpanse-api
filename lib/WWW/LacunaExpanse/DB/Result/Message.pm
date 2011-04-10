package WWW::LacunaExpanse::DB::Result::Message;

use strict;

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(Core));
__PACKAGE__->table('message');
__PACKAGE__->add_columns(qw(
    server_id
    empire_id
    message_id
    subject
    on_date
    sender
    sender_id
    recipient
    recipient_id
    has_read
    has_replied
    has_archived
    in_reply_to
    body_preview
    body
    )
);

__PACKAGE__->set_primary_key('server_id','empire_id','message_id');

1;
