package WWW::LacunaExpanse::Script::Example::Species;

use Pod::Usage;
use Moose;

extends 'WWW::LacunaExpanse::Script';

# This is where the script does it's stuff
sub execute {
    my ($self) = @_;

    my $empire = $self->api->empire;

    print "Empire name = ".$empire->status->name.":\n";
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

WWW::LacunaExpanse::Script::Example::Species;

=head1 SYNOPSIS

  Options
    -help           (this) brief help message

  Use with script_runner.pl as follows.

  ./script_runner.pl -script Example::Species

=head1 OPTIONS

=head1 DESCRIPTION

This is an example script for use with the WWW::LacunaExpanse::Script script_runner.pl
module.

It shows how you can do something simple (in this case just print your Species information.)

=cut
