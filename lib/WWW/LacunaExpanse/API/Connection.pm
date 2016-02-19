package WWW::LacunaExpanse::API::Connection;

use MooseX::Singleton;

use Log::Log4perl;
use Data::Dump qw(dump);
use Data::Dumper;
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
has 'debug_hits'    => (is => 'rw', default => 0);
has 'log'           => (is => 'rw', lazy_build => 1);
has 'rpc_calls'     => (is => 'rw', default => 0);

my $public_key      = 'c200634c-7feb-4001-8d70-d48eb3ff532c';

# Do an auto-login
sub BUILD {
    my ($self) = @_;

    if (defined($self->{username}) and defined($self->{password})) {
        $self->call('/empire', 'login', [{
            name        => $self->username, 
            password    => $self->password, 
            api_key     => $public_key,
        }]);
    }
}

# Build the logger
sub _build_log {
    my ($self) = @_;

    my $log = Log::Log4perl->get_logger('WWW::LacunaExpanse::API::Connection');
    return $log;
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

    my $ps = '';
    if ($params and @$params) {
        $ps = join('|', map {defined $_ ? $_ : ''} @$params);
    }
    $self->log->debug("API-CALL: PATH $path : METHOD $method [$ps]");
#    print Dumper($params);

    my $max_tries = 5;

    my $req;
#    TRIES:
#    while ($max_tries) {
        # TRY
#        eval {
            $req = $self->marshal->call_to_request(
                JSON::RPC::Common::Procedure::Call->inflate(
                    jsonrpc => "2.0",
                    id      => "1",
                    method  => $method,
                    params  => $params,
                ),
                uri => URI->new($self->uri.$path),
            );
#        };
        # CATCH
#        if ($@) {
#            my $e = $@;
#            $self->log->debug("RETRY: ".(6 - $max_tries)." $e");
#            $max_tries--;
#        }
#        else {
#            last TRIES;
#        }
#    }

    $self->log->trace($req->as_string);
#    if ($self->debug) {
#        print "\n############ request ##################\n";
#        print "request = [".$req->as_string."]\n";
#        print "#######################################\n\n";
#    }
    if ($self->debug_hits) {
        # Disable buffering
        my $ofh = select STDOUT;
        $| = 1;
        print '.';
        select $ofh;
    }
    my $resp = $self->user_agent->request($req);

    if ($resp->content =~ m/<html>/) {
        print STDERR $resp->content;
        die;
    }

    my $res = $self->marshal->response_to_result($resp);

    if ($res->error) {
        Carp::croak("RPC Error (" . $res->error->code . "): " . $res->error->message);
    }
    my $deflated = $res->deflate;

    my $rpc_count;
    if (defined $deflated->{result}{empire}) {
        $rpc_count = $deflated->{result}{empire}{rpc_count};
    }
    else {
        $rpc_count = $deflated->{result}{status}{empire}{rpc_count};
    }
    $self->rpc_calls($rpc_count);
#    $self->log->debug("RPC_CALLS: $rpc_count");

    if (not $rpc_count) {
        print "\n############ response ###############\n";
        print "response = [".dump(\$deflated)."]\n";
        print "#######################################\n\n";
}

    if (!$self->session_id                                          # Skip if we've already got it
        and exists $deflated->{result}
        and ref($deflated->{result}) eq 'HASH'                      # unauthenticated calls don't return a HASH ref
        and exists $deflated->{result}{session_id}) {

        $self->session_id($deflated->{result}{session_id});
    }
    # throttle back a script so that it is less than 75 per minutes
    # sleep 1 will reduce it to less than 60 per minute
    sleep 1;
    return $deflated;


}


1;
