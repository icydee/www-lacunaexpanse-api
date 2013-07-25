#!/usr/bin/perl

use Modern::Perl;
use FindBin::libs;
use Config::JSON;
use Data::Dumper;
use Getopt::Long;

use Demo::Script;


# get the script name e.g. --script=Example::Demo
#
my $script_name;
GetOptions("script=s" => \$script_name);

# If no script name given, output generic usage.


# Create an instance of the script.
my $class = "Demo::Script::$script_name";
my $script = $class->new;




$script->get_options;

my @script_configs = $script->configs;

# config is the overall config hash.
my $config;

# config files are in 'etc' or relative to 'etc' and can be overridden on
# the command line. 
#   e.g. --config=demo (etc/demo.json)
#   e.g. --config=/my/dir/myconfig (my/dir/myconfig.json)
#
# multiple config files may be specified.
# Files that come first have precedence
# files that have includes have precedence over the files they include.
#
my @configs = (qw(default));
GetOptions ("config=s@" => \@configs;




# Config Files.
#   Multiple config files may be specified.
#   - The script runner assumes a default file of etc/default.json
#   - Each script may have a default config file, e.g. etc/ExampleDemo.json
#   - One or more config files may be specified on the command line
#       e.g. --config config1.json --config2.json
#
#   - In addition, 


# config files from the command line
# --config 

# over-ride config variables from command line





1;
