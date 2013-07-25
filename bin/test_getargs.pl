#!/usr/bin/perl

use Modern::Perl;
use FindBin::libs;
use Config::JSON;
use Data::Dumper;
use Getopt::Long qw(:config pass_through);
use File::Temp qw(tempfile);
use Carp;
use Data::Format::Pretty::JSON qw(format_pretty);

my $defines;
my $script_name;

# This is the default config
my @configs = 'default';

GetOptions (
    "script=s"  => \$script_name,
);

# Create an instance of the script
my $class = "Temp::$script_name";
eval "require $class";
if ($@) {
    croak "Cannot load class $class";
}
my $script = $class->new;

# Allow the script to get it's command line arguments.
$script->getopt;

# Get any other config files specified on the command line.

my @config_names;
GetOptions (
    "config=s@" => \@config_names,
);

unshift @configs, @config_names,$script->default_config;
@configs = map {$_.".json"} @configs;

my $fh = File::Temp->new;
my $filename = $fh->filename;
print $fh "{\n";
my $line = '"includes" : ["'.join('","', @configs).'"]'."\n";
print $fh $line;
print $fh "}\n";
close($fh);
my $config = Config::JSON->new($filename);

GetOptions ("define=s%" => \$defines);

for my $key (keys %$defines) {
    $config->set($key, $defines->{$key});
}

print "test = [".$config->get("test")."]\n";
1;



=head1 NAME

ServiceNow::Config - Extract data from the A2RM database and provide an export for Service Now

=head1 VERSION

version 1.0

=head1 SYNOPSIS

  use ServiceNow;


=head1 DESCRIPTION






=head2 Config Files



