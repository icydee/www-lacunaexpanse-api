package Temp::Foo;

use Moose;


has default_config => (
    is      => 'ro',
    isa     => 'Str',
    default => 'foo',
);

sub getopt {
}

1;
