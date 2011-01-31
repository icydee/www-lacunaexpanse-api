#!perl
use Modern::Perl;
use Data::Dumper;
use DateTime;
use Path::Class;
use FindBin       qw($Bin);
use List::Util    qw(min max);
use YAML::Any     qw(Dump);
use Getopt::Long  qw(GetOptions);
use File::HomeDir;
use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::API::DateTime;
use WWW::LacunaExpanse::Agent::ShipBuilder;

my $config;
my $format;

GetOptions(
    'config|cfgpath|c=s' => \$config,
    'format|f=s'         => \$format,
) or die usage();

# cross platform support for home directories
if ($config =~ m/\~/) {
    my $homedir = File::HomeDir->my_home();
    $config =~ s/\~/$homedir/;
}

$config ||= dir($Bin, '..', 'myaccount.yml');
unless (-e $config and -f $config) {
    print "Config file specified does not exist! $config\n";
    usage();
}

$format ||= 'txt';
unless ($format =~ m/^(?:txt|csv)$/) {
    print "Unsupported format specified: $format\n";
    usage();
}

my $c = YAML::Any::LoadFile($config) or die $!;

my $api = WWW::LacunaExpanse::API->new({
    uri         => $c->{uri}        || $c->{server_uri},
    username    => $c->{username}   || $c->{empire_name},
    password    => $c->{password}   || $c->{empire_password},
    debug_hits  => $c->{debug_hits} || 0,
});
my $empire = $c->{username}   || $c->{empire_name};
my %fleet_type;
my %ship_of;
my %fleet_of;
for my $colony (@{$api->my_empire->colonies}) {
    printf "%s (%d:%d)\n",  $colony->name, $colony->x, $colony->y;

    # get all offensive ship types at first shipyard
    if (!%fleet_type) {
        my $shipyard = $colony->shipyard;
        if ($shipyard) {
            @fleet_type{map { $_->{type}} @{$shipyard->get_buildable('War')} } = ();
            @fleet_type{qw(spy_shuttle spy_pod smuggler_ship scanner surveyor)} = ();
        }
    }

    my $space_port = $colony->space_port;
    next if !$space_port;
    my $fc = $fleet_of{$colony->name} ||= {
        docks_total => 0,
        docks_open  => 0,
        ships       => {},
    };
    $fc->{docks_open} = $fc->{docks_total} = $space_port->max_ships;
    for my $ship ($space_port->all_ships) {
        my $type = $ship->type;
        $fc->{ships}{$type}++;
        $ship_of{$type}++;
        $fc->{docks_open}--;
    }
}

# fleet ship type abbreviations
for my $t (keys %fleet_type) {
    $fleet_type{$t} = $t =~ /\d$/ ? uc(substr($t,0,2) . substr($t,-1,1))                       # 2 chars and number
                    : $t =~ /_/   ? q{!} . join('', map {ucfirst(lc(substr($_,0,2)))} split /_/, $t)  # 2 letters from each word
                    :               uc(substr($t,0,3))                                         # 1st 3 letters
                    ;
}

print
    '|| '
    ,join(' || '
          ,map({"'''$_'''"} qw(colony docks open))
          ,map({"'''$fleet_type{$_}'''"} sort(keys %fleet_type)))
    ,' ||'
    ,"\n";
my ($do, $dt) = (0,0);
for my $colony (sort keys %fleet_of) {
    my $fcs = $fleet_of{$colony}{ships};
    $dt += $fleet_of{$colony}{docks_total};
    $do += $fleet_of{$colony}{docks_open};
    print('|| '
          ,join(' || '
               ,$colony
               ,@{$fleet_of{$colony}}{qw(docks_total docks_open)}
               ,map { exists $fcs->{$_} ? $fcs->{$_} : 0 } sort(keys %fleet_type))
          ,' ||'
          ,"\n");
}
print('|| '
      ,join(' || ',"[$empire]", $dt, $do, map { exists $ship_of{$_} ? $ship_of{$_} : 0 } sort(keys %fleet_type))
      ,' ||'
      ,"\n");

exit;

sub usage {
    my $prog = $0;
    $prog =~ s/.*(?:\\|\/)//;
    print <<"EOF";

usage: $prog --config=~/myaccount.yml [--format=csv]

Creates a fleet summary report

Options:
    --config or -c    required    location of YAML config file
    --format or -f    optional    output format (default: txt)

EOF
    exit;
}



1;
__END__
