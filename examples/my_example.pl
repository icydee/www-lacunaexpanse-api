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

my $stars = $api->find({star => 'Oss Gairvi'});        # beermat's home star
#my $stars = $api->find({star => 'Oosch Fraeleu Stea'});
for my $star (@$stars) {
    print $star;
    my $incoming_probe = $star->incoming_probe;
    if ($incoming_probe) {
        print "A probe arrives here at $incoming_probe\n";
    }
}


exit;
my $empires = $api->find({empire => 'icyd'});
for my $empire (@$empires) {
    print $empire;
}


#my $my_empire = $api->my_empire;
#
#print dump($my_empire->name);
#print "My Empire Name is [".$my_empire->name."]\n";
#
#for my $colony (@{$my_empire->colonies}) {
#    print "$colony\n";
#    print "Colony Name: '".$colony->name."' at ".$colony->x."-".$colony->y." water capacity ".$colony->water_capacity."\n";
#}
#
#exit;


#my $empire_rank     = $api->empire_rank({});
#my $total_empires   = $empire_rank->count;
#
#print "Total empires = '$total_empires'\n";
#my $count = 0;
#
#while ((my $empire_stats = $empire_rank->next) && $count < 14) {
#    my $empire = $empire_stats->empire;
#    print "Empire [".$empire->id."]\t name        : ".$empire->name."\n";
#    if ($empire->colony_count > 1) {
#        print "    Worth checking up.\n";
#        for my $colony (@{$empire->known_colonies}) {
#            print "        Colony ".$colony->name." location ".$colony->x."-".$colony->y."\n";
#            if ($colony->can_see) {
#                print "        CAN SEE orbit [".$colony->orbit."]\n";
#            }
#        }
#    }
#    else {
#        print "    Not worth bothering with\n";
#    }
#    $count++;
#}



#my $page_number = 1;
#my $total_pages = 1;
#do {
#    my $empire_rank = $api->empire_rank({page_number => $page_number});
#    $total_pages = $empire_rank->total_pages;
#    if ($page_number == 1) {
#        print "Total pages   =[$total_pages]\n";
#        print "Total empires =[".$empire_rank->total_empires."]\n";
#    }
#
#    for my $empire_stat (@{$empire_rank->empires}) {
#        my $empire = $empire_stat->empire;
#        print "Empire name        : ".$empire->name."\n";
#        if ($empire->colony_count > 1) {
#            print "    Worth checking up.\n";
#            for my $colony (@{$empire->known_colonies}) {
#                print "        Colony ".$colony->name." location ".$colony->x."-".$colony->y."\n";
#            }
#        }
#        else {
#            print "    Not worth bothering with\n";
#        }
#    }
#    $page_number++;
#} while ($page_number < $total_pages && $page_number < 3);

#print dump(\$empire_rank);




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


