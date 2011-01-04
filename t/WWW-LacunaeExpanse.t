use strict;
use warnings;

use Test::More tests => 5;
BEGIN { use_ok('WWW::LacunaExpanse::API') };

eval { WWW::LacunaExpanse::API->new };
like($@, qr/Attribute \(uri\) is required/, 'Exception without uri');

my $client = eval { WWW::LacunaExpanse::API->new(uri => 'https://us1.lacunaexpanse.com') };
isa_ok($client, 'WWW::LacunaExpanse::API');

my $is_available_false = eval { $client->is_name_available('Jandor Trading') };
ok($is_available_false == 0, 'is_name_available false');

my $is_available_true = eval { $client->is_name_available('Z1y3W5x7D6c4B2a') };
ok($is_available_true == 1, 'is_name_available true');

1;
__END__
