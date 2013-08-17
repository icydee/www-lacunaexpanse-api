package WWW::LacunaExpanse::Script::Example::Empire;

use Pod::Usage;
use Moose;

extends 'WWW::LacunaExpanse::Script';

# This is where the script does it's stuff
sub execute {
    my ($self) = @_;

    my $empire = $self->api->empire;

    my $public_profile = $empire->get_public_profile($empire->id);

    print "My Public Profile says\n";
    print "  id             : ".$public_profile->id."\n";
    print "  name           : ".$public_profile->name."\n";
    print "  medals         : ".scalar(@{$public_profile->medals})."\n";
    foreach my $medal (@{$public_profile->medals}) {
        print "    name         ".$medal->name."\n";
        print "      times      ".$medal->times_earned."\n";
    }

    my $own_profile = $empire->own_profile;

    print "My Private Profile says\n";
    print "  id             : ".$own_profile->id."\n";
    print "  status_message : ".$own_profile->status_message."\n";
    foreach my $medal (@{$own_profile->medals}) {
        print "    name         : ".$medal->name."\n";
        print "      times      : ".$medal->times_earned."\n";
        print "      public     : ".$medal->public."\n";
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

WWW::LacunaExpanse::Script::Example::Empire;

=head1 SYNOPSIS

  Options
    -help           (this) brief help message

  Use with script_runner.pl as follows.

  ./script_runner.pl -script Example::Empire

=head1 OPTIONS

=head1 DESCRIPTION

This is an example script for use with the WWW::LacunaExpanse::Script script_runner.pl
module.

It shows how you can do something simple (in this case interact with the /empire API.)

=cut
