package WWW::LacunaExpanse::Script::Example::Map;

use Pod::Usage;
use Moose;
use Data::Dumper;

use WWW::LacunaExpanse::API::Map;

extends 'WWW::LacunaExpanse::Script';

# This is where the script does it's stuff
sub execute {
    my ($self) = @_;

    my $map = $self->api->map;

    my $starmap = $map->get_star_map({
        left    => 0,
        right   => 20,
        top     => 20,
        bottom  => 0,
    });
    my $stars = $starmap->stars;
    print "There are ".scalar(@{$stars})." stars in 0|0 to 20|20\n";

    $starmap->left(20);
    $starmap->right(40);
    $starmap->update;
    $stars = $starmap->stars;
    print "There are ".scalar(@{$stars})." stars in 20|0 to 40|20\n";

    my $star = $stars->[0];
    if ($star->bodies) {
        print "There are ".scalar(@{$star->bodies})." bodies around ".$star->name."\n";
    }
    else {
        print "We don't have a probe at star ".$star->name."\n";
    }

    # check for any stars that begin with 'dil'

    $stars = $map->find_star('dil');
    print "There are ".scalar(@$stars)." stars that start 'dil'\n";

    # get a specific star

    $star = $map->get_star(100);
    print "Star with ID=100 is ".$star->name."\n";

    # Check star for incoming probes
    #
    my $date = $map->check_star_for_incoming_probe($star->id);
    if ($date) {
        print "Probe is incoming and due at $date\n";
    }
    else {
        print "Star has no incoming probes\n";
    }
}

# Print a usage message by using your POD
# (You *did* write some POD didn't you?)
# 
sub usage {
    pod2usage(-input => __FILE__);

}
1;

=cut

=head1 NAME

WWW::LacunaExpanse::Script::Example::Map;

=head1 SYNOPSIS

  Options
    -help           (this) brief help message

  Use with script_runner.pl as follows.

  ./script_runner.pl --script Example::Map

=head1 OPTIONS

=head1 DESCRIPTION

This script demonstrates the calls for the Map API.

=cut
