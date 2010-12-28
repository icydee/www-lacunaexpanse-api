package WWW::LacunaExpanse::API::Connection;

use MooseX::Singleton;

use Data::Dump qw(dump);
use LWP::UserAgent;
use JSON::RPC::Common::Marshal::HTTP;
use Carp;

our @CARP_NOT = qw(
    WWW::LacunaExpanse::API
    WWW::LacunaExpanse::API::Empire
);

# This class communicates with the Lacuna Expanse Server

# Private attributes
has 'uri'           => (is => 'ro', required => 1);
has 'username'      => (is => 'ro', required => 1);
has 'password'      => (is => 'ro', required => 1);
has 'user_agent'    => (is => 'ro', lazy_build => 1);
has 'marshal'       => (is => 'ro', lazy_build => 1);
has 'session_id'    => (is => 'rw');
has 'debug'         => (is => 'rw', default => 0);

my $public_key      = 'c200634c-7feb-4001-8d70-d48eb3ff532c';

# Do an auto-login
sub BUILD {
    my ($self) = @_;

    $self->call('/empire', 'login', [$self->username, $self->password, $public_key]);
}

# lazy build the User Agent
sub _build_user_agent {
    my ($self) = @_;

    return LWP::UserAgent->new(env_proxy => 1);
}

# lazy build the Marshal
sub _build_marshal {
    my ($self) = @_;

    return JSON::RPC::Common::Marshal::HTTP->new;
}

# make a call to the server
sub call {
    my ($self, $path, $method, $params) = @_;

    my $req = $self->marshal->call_to_request(
        JSON::RPC::Common::Procedure::Call->inflate(
            jsonrpc => "2.0",
            id      => "1",
            method  => $method,
            params  => $params,
        ),
        uri => URI->new($self->uri.$path),
    );

    if ($self->debug) {
        print "\n############ request ##################\n";
        print "request = [".$req->as_string."]\n";
        print "#######################################\n\n";
    }
    print '.';
    my $resp = $self->user_agent->request($req);

#    print "response = [".$resp->as_string."]\n";

    my $res = $self->marshal->response_to_result($resp);

#    $self->_set_total_calls($self->total_calls + 1);


    if ($res->error) {
        Carp::croak("RPC Error (" . $res->error->code . "): " . $res->error->message);
    }
    my $deflated = $res->deflate;
    if ($self->debug) {
        print "\n############ response ###############\n";
        print "response = [".dump(\$deflated)."]\n";
        print "#######################################\n\n";
    }

    if ($deflated->{result}{session_id}) {
        $self->session_id($deflated->{result}{session_id});
    }

    return $deflated;


}


1;
