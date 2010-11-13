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

my $page_number = 1;
my $total_pages = 1;
do {
    my $empire_rank = $api->empire_rank({page_number => $page_number});
    $total_pages = $empire_rank->total_pages;
    if ($page_number == 1) {
        print "Total pages   =[$total_pages]\n";
        print "Total empires =[".$empire_rank->total_empires."]\n";
    }

    for my $empire_stat (@{$empire_rank->empires}) {
        my $empire = $empire_stat->empire;
        print "Empire name        : ".$empire->name."\n";
        if ($empire->colony_count > 1) {
            print "    Worth checking up.\n";
            for my $colony (@{$empire->known_colonies}) {
                print "        Colony ".$colony->name." location ".$colony->x."-".$colony->y."\n";
            }
        }
        else {
            print "    Not worth bothering with\n";
        }
    }
    $page_number++;
} while ($page_number < $total_pages && $page_number < 3);

#print dump(\$empire_rank);



#my $empires = $api->find({empire => 'icydee-2'});
#for my $empire (@$empires) {
#    print "Empire name : ".$empire->name."\n";
#    print "Known Colonies\n";
#    for my $colony (@{$empire->known_colonies}) {
#        print "    Colony name ".$colony->name."\n";
#        print "    Colony location ".$colony->x."-".$colony->y."\n";
#        print "    Has Uraninite ".$colony->ore->uraninite."\n";
#        print "    On Star '".$colony->star->name."' position ".$colony->star->x."-".$colony->star->y."\n";
##        print dump($colony->star);
#    }
#}

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


