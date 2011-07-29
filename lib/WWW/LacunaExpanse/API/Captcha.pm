package WWW::LacunaExpanse::API::Captcha;

use Moose;
use Data::Dumper;
use Carp;

with 'WWW::LacunaExpanse::API::Role::Connection';

# Attributes
has 'guid'          => (is => 'rw');
has 'solution'      => (is => 'rw');

my $path = '/captcha';


sub fetch {
    my ($class) = @_;

    my $connection = WWW::LacunaExpanse::API::Connection->instance;
    my $log = Log::Log4perl->get_logger('WWW::LacunaExpanse::API::Connection');

TRY_AGAIN:
    my $result = $connection->call($path, 'fetch', [$connection->session_id]);

    my $guid    = $result->{result}{guid};
    my $url     = $result->{result}{url};

#    $log->error("CAPTCHA: GUID=$guid");
    $log->error("SOLVE THE CAPTCHA: URL=$url");

    print "Give the solution to the captcha (and press return) :";
    my $captcha = <>;
    chomp $captcha;

    eval {
        my $result = $connection->call($path, 'solve', [$connection->session_id, $guid, $captcha]);
    };
    if ($@) {
        my ($rpc_error) = $@ =~ /RPC Error \((\d\d\d\d)\)/;
        $log->error("RPC error is $rpc_error");
        if ($rpc_error == 1014) {
            goto TRY_AGAIN;
        }
    }

}
