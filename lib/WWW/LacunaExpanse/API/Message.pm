package WWW::LacunaExpanse::API::Message;

use Moose;
use Carp;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'cached'            => (is => 'ro');
has 'body_preview'      => (is => 'rw');

my $path = '/inbox';

my @simple_strings  = qw(subject from from_id to to_id has_read has_replied body has_archived in_reply_to);
my @date_strings    = qw(date);
my @other_strings   = qw(recipients tags attachments);

for my $attr (@simple_strings, @date_strings, @other_strings) {
    has $attr => (is => 'ro', writer => "_$attr", lazy_build => 1);

    __PACKAGE__->meta()->add_method(
        "_build_$attr" => sub {
            my ($self) = @_;
            $self->update;
            return $self->$attr;
        }
    );
}

# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

    $self->connection->debug(0);
    my $result = $self->connection->call($path, 'read_message',[$self->connection->session_id, $self->id]);
    $self->connection->debug(0);

    my $message = $result->{result}{message};

    $self->simple_strings($message, \@simple_strings);

    $self->date_strings($message, \@date_strings);

    # other strings
    $self->_recipients('TBD');
    $self->_tags('TBD');
    $self->_attachments('TBD');
}

1;
