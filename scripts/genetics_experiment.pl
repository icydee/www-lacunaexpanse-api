#!/home/icydee/localperl/bin/perl

# Script to carry out genetics experiment. Specify the
# spies name and the affinity you want to try and graft in the genetics.yml file

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;

# Load configurations

my $my_account      = YAML::Any::LoadFile("$Bin/myaccount.yml");
my $genetics_config = YAML::Any::LoadFile("$Bin/genetics.yml");

my $api = WWW::LacunaExpanse::API->new({
    uri         => $my_account->{uri},
    username    => $my_account->{username},
    password    => $my_account->{password},
});

my $my_empire       = $api->my_empire;
my ($colony)        = @{$my_empire->find_colony($genetics_config->{colony})};

print "Genetics lab is on colony ".$colony->name."\n";

my $genetics_lab    = $colony->genetics_lab;

#print $genetics_lab;

# Look for spy specified in the config
my ($graft) = grep {$_->spy->name eq $genetics_config->{spy_name}} @{$genetics_lab->grafts};

if ($graft) {
    my $spy = $graft->spy;
    print "Attempting graft from spy '".$spy->name."'\n";
    my $results = $genetics_lab->run_experiment($spy, $genetics_config->{affinity});

    print Dumper(\$results);
}
else {
    print "ERROR: That spy could not be found. Did he die in an earlier experiment?\n";
}


1;
