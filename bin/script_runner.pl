#!/usr/bin/perl

use Modern::Perl;
use FindBin::libs;
use FindBin;
use Config::JSON;
use Data::Dumper;
use Getopt::Long qw(:config pass_through);
use Pod::Usage;
use File::Temp qw(tempfile);
use File::Spec;
use Class::Load qw(try_load_class);
use Carp;
use Data::Format::Pretty::JSON qw(format_pretty);
use WWW::LacunaExpanse::API;

my $defines;
my $script_name;

# This script assumes a default config file, etc/default.json
my @configs = 'default';
my $help    = 0;

# First determine what script you want to run. This is a required field.
GetOptions (
    "script=s"  => \$script_name,
    "help|?"    => \$help,
) or pod2usage(2);

# Usage if help without a script name
pod2usage(1) if $help and not $script_name;

# Attempt to load the class and create an instance
my $class = "WWW::LacunaExpanse::Script::$script_name";
my ($loaded, $error) = try_load_class($class);
if (not $loaded) {
    croak "Cannot load class $class - $error";
}

my $script = $class->new;

# Help on using the script itself
$script->usage if $help;


# Allow the script to get it's own command line arguments (if any)
$script->getopt;


# Now add in any other config files specified on the command line.
my @config_names;
GetOptions (
    "config=s@" => \@config_names,
);

if ($script->has_default_config) {
    unshift @configs, @config_names,$script->default_config;
}
else {
    unshift @configs, @config_names;
}

# add the base path to the etc directory.

my ($volume,$directories,$file) = File::Spec->splitpath($FindBin::Bin);
my @dirs        = File::Spec->splitdir($directories);
my $etc_dir     = File::Spec->catdir(@dirs,'etc');

my @full_configs;
for my $config (@configs) {
    # this gives us the root directory.

    my $full_path = File::Spec->catpath($volume,$etc_dir,"$config.json");
    push @full_configs, $full_path;
}

# We have to create a temp file to 'include' each config file since
# Config::JSON does not (yet) support multiple config files
# 
my $fh = File::Temp->new;
my $filename = $fh->filename;
print $fh "{\n";
my $line = '"includes" : ["'.join('","', @full_configs).'"]'."\n";
print $fh $line;
print $fh "}\n";
close($fh);
my $config = Config::JSON->new($filename);


# We can now process all the config defines from the command line.
GetOptions ("define=s%" => \$defines);

for my $key (keys %$defines) {
    $config->set($key, $defines->{$key});
}

# Finally! we have a valid config. Pass it to the script.

$script->config($config);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $config->get('connect/uri'),
    username    => $config->get('connect/username'),
    password    => $config->get('connect/password'),
});

$script->api($api);

# And let the script actually do it's stuff.

$script->execute;

1;



=head1 NAME

script_runner.pl - command line tool that will run any WWW::LacunaExpanse::Script

=head1 VERSION

version 1.0

=head1 SYNOPSIS

  ./script_runner.pl -script MyScript  -config abc  -define user=myEmpire -define pass=secret

=head1 DESCRIPTION

B<script_runner.pl> is a Perl program that will run scripts written to control Empires on Lacuna Expanse. 
See http://www.lacunaexpanse.com

Lacuna Expanse has a published API which allows people to write scripts to enable them to automate some of
the processes of running their Empire. Although everything can be controlled manually through the Web Browser
Client, or the iPhone client, for some perverse reason people have fun writing code to do it for them!

The library L<WWW::LacunaExpanse::API> is a client which provides an Object Oriented interface to the Lacuna Expanse API
(see http://us1.lacunaexpanse.com/api/>

It is also an attempt to provide a unified interface to the scripts and to aid the development of such scripts
by removing much of the boilerplate that has previously been used by stand alone scripts.

All scripts written to this specification should be in the L<WWW::LacunaExpanse::Script> namespace.

=head2 Config Files

By default, configuration files are held in the B<etc> directory and all have the extension B<.json>

Multiple configuration files can be specified. The script runner assumes a default config file which
is B<etc/default.json>

Typically a script will also have a default configuration file, e.g. WWW::LacunaExpanse::Script::Example::FleetSummary
would have a default config file B<etc/example/fleet_summary.json>

Config files can be specified on the command line.

  script_runner.pl -script Example::FleetSummary -config example/fleet_summary

Note, you don't need to specify the etc directory (that is assumed) or the extension .json, that is also assumed.

Config files can contain their own config keys, or they can override a key/value from another config file in which case
the order of the config files determines which one takes priority.

As an example.

  script_runner.pl -script MyScript -config abc -config xyz

  there are four config files used here and they are processed in this order.

  etc/abc.json
  etc/xyz.json
  etc/myscript.json     (the default config file specified by the MyScript file)
  etc/default.json      (the default config file specified by script_runner.pl)

Each of the config files will contribute to the config, adding key/value pairs.

If the same key appears in more than one file.

  etc/default.json 
  {
    "user"   : "myEmpire",
    "server" : "us1",
  }

  etc/abc.json
  {
    "user"   : "anotherEmpire",
    "server" : "pt",
  }

Then the B<user> and B<server> keys in the default.json file will be overridden by the contents of
the abc.json file. This is because the abc.json file appears before the default.json file so it has
a higher priority. The default.json file always has the lowest priority.

If you look at the documentation for L<Config::JSON> you will see that config files can themselves
B<include> other config files, this allows you to have a hierarchy of config files and if you want to
go that route you should read the documentation on the priority of the master file and the include files,
but that way lies madness!

=head2 Command line arguments

Ideally, most configuration should take place in a config file since command line arguments can get very
long if you try to configure everything that way. However, there are a number of standard command line
arguments.

=head3 -script

 -script Example::FleetSummary

This defines the name of the script you want to run and it assumes the prefix of B<WWW::LacunaExpanse::Script>
in this case it will run the script WWW::LacunaExpanse::Script::Example::FleetSummary

=head3 -config

 -config abc -config example/xyz

Each B<-config> specifies a configuration file. You can specify as many config files as you wish.
See the Config section to understand the order of precidence for these files.

=head3 -define

 -define user=myEmpire -define pass=mySecretPassword -define my/long/config/item=foo

After all the config files have been merged and resolved, you can still modify individual config values 
from the command line with the B<-define> arguments. These are the highest priority so if they match
a value in a config file the B<-define> will take priority.

For more details on how to define deeply nested config values refer to L<Config::JSON>

