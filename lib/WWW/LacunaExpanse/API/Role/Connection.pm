package WWW::LacunaExpanse::API::Role::Connection;

use Moose::Role;
use WWW::LacunaExpanse::API::Connection;
use WWW::LacunaExpanse::API::DateTime;

has 'connection'        => (is => 'ro', lazy_build => 1);

sub _build_connection {
    return WWW::LacunaExpanse::API::Connection->instance;
}

sub simple_strings {
    my ($self, $data, $strings) = @_;

    # simple strings
    for my $attr (@$strings) {

#print "<<<>>> Adding simple string [$attr] [".$data->{$attr}."]<<<>>>\n";
        my $method = "_$attr";
        $self->$method($data->{$attr});
    }
}

sub date_strings {
    my ($self, $data, $strings) = @_;

    # date strings
    for my $attr (@$strings) {
        my $date = $data->{$attr};
        my $method = "_$attr";
        $self->$method(WWW::LacunaExpanse::API::DateTime->from_lacuna_string($date));
    }
}
1
