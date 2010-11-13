#!/home/icydee/localperl/bin/perl
use strict;
use warnings;

use lib "lib";
use WWW::LacunaExpanse::API;

use Data::Dump qw(dump);

#### Configuration ####
my $uri         = 'https://us1.lacunaexpanse.com';
my $username    = 'icydee-2';
my $password    = 'Ammal56aam';

#### End of Configuration ####

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

#my $empire_rank = $api->empire_rank({page_number => 1});
#print "Total empires=[".$empire_rank->total_empires."]\n";
#print "There are [".scalar(@{$empire_rank->empires})."] empires on this page\n";
#for my $empire_stat (@{$empire_rank->empires}) {
#    print "Empire name        : ".$empire_stat->empire->name."\n";
#    print "Empire description : ".$empire_stat->empire->description."\n";
#    print "Building count     : ".$empire_stat->building_count."\n";
#    last; #to stop processing all 25 for test purposes
#}

#print dump(\$empire_rank);



my $empires = $api->find({empire => 'icydee-2'});
for my $empire (@$empires) {
    print "Empire name : ".$empire->name."\n";
    print "Known Colonies\n";
    for my $colony (@{$empire->known_colonies}) {
        print "    Colony name ".$colony->name."\n";
    }
}

#
#for my $empire (@$empires) {
#    print "Empire founded on ".$empire->date_founded."\n";
#    print "Description = [".$empire->description."]\n";
#    print "Name = [".$empire->name."]\n";
#    print "Founded = [".$empire->date_founded->ymd."]\n";
#    print "Empire known colonies = [".$empire->known_colonies."]\n";
#    my $alliance = $empire->alliance;
#    if ($alliance) {
#        print "Alliance = [".$alliance."]\n";
#        print "Alliance ID = [".$alliance->id."]\n";
#        print "Alliance name = [".$alliance->name."]\n";
#        print "Alliance leader = [".$alliance->leader->name."]\n";
#        for my $member (@{$alliance->members}) {
#            print "Alliance member [".$member->name."]\n";
#        }
#    }
#}


