package WWW::LacunaExpanse::API::Ores;

use Moose;
use Carp;

# Attributes
has 'anthracite'        => (is => 'rw');
has 'bauxite'           => (is => 'rw');
has 'beryl'             => (is => 'rw');
has 'chalcopyrite'      => (is => 'rw');
has 'chromite'          => (is => 'rw');
has 'fluorite'          => (is => 'rw');
has 'galena'            => (is => 'rw');
has 'goethite'          => (is => 'rw');
has 'gold'              => (is => 'rw');
has 'gypsum'            => (is => 'rw');
has 'halite'            => (is => 'rw');
has 'kerogen'           => (is => 'rw');
has 'magnetite'         => (is => 'rw');
has 'methane'           => (is => 'rw');
has 'monazite'          => (is => 'rw');
has 'rutile'            => (is => 'rw');
has 'sulfur'            => (is => 'rw');
has 'trona'             => (is => 'rw');
has 'uraninite'         => (is => 'rw');
has 'zircon'            => (is => 'rw');


# Stringify
use overload '""' => sub {
    my $ore = $_[0];
    my $str = "    Ores\n";
    $str .= "      anthracite   : ".$ore->anthracite."\n";
    $str .= "      bauxite      : ".$ore->bauxite."\n";
    $str .= "      beryl        : ".$ore->beryl."\n";
    $str .= "      chalcopyrite : ".$ore->chalcopyrite."\n";
    $str .= "      chromite     : ".$ore->chromite."\n";
    $str .= "      fluorite     : ".$ore->fluorite."\n";
    $str .= "      galena       : ".$ore->galena."\n";
    $str .= "      goethite     : ".$ore->goethite."\n";
    $str .= "      gold         : ".$ore->gold."\n";
    $str .= "      gypsum       : ".$ore->gypsum."\n";
    $str .= "      halite       : ".$ore->halite."\n";
    $str .= "      kerogen      : ".$ore->kerogen."\n";
    $str .= "      magnetite    : ".$ore->magnetite."\n";
    $str .= "      methane      : ".$ore->methane."\n";
    $str .= "      monazite     : ".$ore->monazite."\n";
    $str .= "      rutile       : ".$ore->rutile."\n";
    $str .= "      sulfur       : ".$ore->sulfur."\n";
    $str .= "      trona        : ".$ore->trona."\n";
    $str .= "      uraninite    : ".$ore->uraninite."\n";
    $str .= "      zircon       : ".$ore->zircon."\n";
    return $str;
};

1;
