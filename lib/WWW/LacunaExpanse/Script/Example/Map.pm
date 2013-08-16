package WWW::LacunaExpanse::Script::Example::Map;

use Pod::Usage;
use Moose;

use WWW::LacunaExpanse::API::Map;

extends 'WWW::LacunaExpanse::Script';

# This is where the script does it's stuff
sub execute {
    my ($self) = @_;

    my $map = $self->api->map;
    print "map = [$map]\n";
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

  ./script_runner.pl -script Example::Map

=head1 OPTIONS

=head1 DESCRIPTION

This script demonstrates the calls for the Map API.

=cut
