package WWW::LacunaExpanse::API::Inbox;

use Moose;
use Carp;
use Data::Dumper;

use WWW::LacunaExpanse::API::Message;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'page_number'       => (is => 'rw', default => 1);
has 'index'             => (is => 'rw', default => 0);

my @simple_strings      = qw(message_count);
my @other_strings       = qw(messages);

for my $attr (@simple_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->view_inbox;
            return $self->$attr;
        }
    );
}

# Reset to the first record
#
sub reset_message {
    my ($self) = @_;

    $self->index(0);
    $self->page_number(1);
}

# Return the next Message in the List
#
sub next_message {
    my ($self) = @_;

    if ($self->index >= $self->message_count) {
        return;
    }

    my $page_number = int($self->index / 25) + 1;
    if ($page_number != $self->page_number) {
        $self->page_number($page_number);
        $self->view_inbox;
    }
    my $message = $self->messages->[$self->index % 25];
    $self->index($self->index + 1);
    return $message;
}

# Return all messages
#
sub all_messages {
    my ($self, $type) = @_;

    my @messages;
    $self->reset_message;
    while (my $message = $self->next_message) {
        push @messages, $message;
    }

    return @messages;
}


# Return the total number of messages
#
sub count_messages {
    my ($self) = @_;

    return $self->message_count;
}

# Refresh the object from the Server
#
sub view_inbox {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call('/inbox', 'view_inbox',[
        $self->connection->session_id, {page_number => $self->page_number}]);

    $self->connection->debug(0);

    $result = $result->{result};

    $self->simple_strings($result, \@simple_strings);


    # other strings
    my @messages;
    for my $message_hash (@{$result->{messages}}) {

        my $message = WWW::LacunaExpanse::API::Message->new({
            id              => $message_hash->{id},
            subject         => $message_hash->{subject},
            date            => WWW::LacunaExpanse::API::DateTime->from_lacuna_string($message_hash->{date}),
            from            => $message_hash->{from},
            from_id         => $message_hash->{from_id},
            to              => $message_hash->{to},
            to_id           => $message_hash->{to_id},
            has_read        => $message_hash->{has_read},
            has_replied     => $message_hash->{has_replied},
            body_preview    => $message_hash->{body_preview},
            tags            => $message_hash->{tags},
        });

        push @messages, $message;
    }
    $self->_messages(\@messages);
}


sub total_pages {
    my ($self) = @_;

    return int($self->message_count / 25);
}


# Refresh the object from the Server
#
sub refresh {
    my ($self) = @_;

    $self->get_summary;
    $self->view_inbox;
}

# Archive a list of messages
#
sub archive_messages {
    my ($self, $messages) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call('/inbox', 'archive_messages',[
        $self->connection->session_id, $messages]);

    $self->connection->debug(0);
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
