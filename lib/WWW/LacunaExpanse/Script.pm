package WWW::LacunaExpanse::Script;

use Pod::Usage;
use Moose;
use Carp;
use Path::Class;

has config => (
    is      => 'rw',
    isa     => 'Config::JSON',
);

has api => (
    is      => 'rw',
    isa     => 'WWW::LacunaExpanse::API',
);

has has_default_config => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

# This is the name of the config file that this script uses
has default_config => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    builder => '_build_default_config',
);

# Create a default config file based on the class name.
# e.g. WWW::LacunaExpanse::Script::Foo::Bar would have a config file
# in etc/foo/bar.json
#
sub _build_default_config {
    my ($self) = @_;

    my $config_file = ref $self;
    $config_file =~ s/WWW::LacunaExpanse::Script:://;
    $config_file = lc($config_file);
    my $dir = dir(split('::', $config_file));
    return "$dir";
}


# I'm not sure we need any options. Pretty much everything can be done
# with a -config file or a -define or both!
#
sub getopt {
}

sub usage {
    croak "You have to define a 'usage' method!";

}

# This is where the script does it's stuff
sub execute {
    croak "You have to define an 'execute' method!";
}


=head1 NAME

WWW::LacunaExpanse::Script;

=head1 SYNOPSIS

  Options
    -help           (this) brief help message

=head1 OPTIONS

=head1 DESCRIPTION

This is the base module that should be extended by every script in the WWW::LacunaExpanse::Script
namespace.

You need to implement the following methods

=head2 usage

You should probably use the POD so that you can generate your Usage message from it as follows

    sub getopt {
        pod2usage(-input => __FILE__);  
    }

=head2 execute

This is where you... do your stuff...

    sub execute {
        my ($self) = @_;

        my $empire = $self->api->empire;
        
        # do the rest of your stuff here...
    }
    
=cut

1;
