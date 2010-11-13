package WWW::LacunaExpanse::API::Body;

use Moose;
use Carp;

# Attributes
has 'id'                => (is => 'ro', required => 1);
has 'connection'        => (is => 'ro', lazy_build => 1);
has 'cached'            => (is => 'ro');

my $path = '/empire';

my @simple_strings  = qw(image name orbit size type water x y);
my @date_strings    = qw();
my @other_strings   = qw(ore star empire);

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

sub _build_connection {
    my ($self) = @_;

    return WWW::LacunaExpanse::API::Connection->instance;
}

# Refresh the object from the Server
#
sub update {
    my ($self) = @_;

    my $result = $self->connection->call($path, 'get_status',[$self->connection->session_id, $self->id]);

    $result = $result->{body};

    # simple strings
    for my $attr (@simple_strings) {
        my $method = "_$attr";
        $self->$method($result->{$attr});
    }

    # date strings
    for my $attr (@date_strings) {
        my $date = $result->{$attr};
        my $method = "_$attr";
        $self->$method(WWW::LacunaExpanse::API::DateTime->from_lacuna_string($date));
    }

    # other strings
    $self->ore('TBD');
    $self->star('TBD');
    $self->empire('TBD');
}

1;
