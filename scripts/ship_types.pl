#!/usr/bin/perl

# Get all ship types buildable

use Modern::Perl;
use FindBin::libs;
use Data::Dumper;

use WWW::LacunaExpanse::API;

my $api = WWW::LacunaExpanse::API->new({
    uri         => "http://le.icydee.com:8080",
    username    => "Lacuna Expanse Corp",
    password    => "secret56",
});

my $empire = $api->empire;


my @colonies = @{$empire->status->planets};

for my $colony (@colonies) {
    my $type = $colony->type;
    print STDERR "EMPIRE = [".$colony->empire."]\n";

    print STDERR Dumper($colony->empire);
    print STDERR "PLANETS = [".$colony->empire->planets."]\n";
    print STDERR "PLANET[0] = [".$colony->empire->planets->[0]."]\n";
    
    print STDERR $colony->empire->planets->[0]->water_stored."\n";
}



1;
