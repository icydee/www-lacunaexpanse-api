use 5.010000;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'WWW::LacunaExpanse',
    VERSION      => 0.001,   # VERSION_FROM => 'lib/WWW/LacunaExpanse.pm',    # finds $VERSION
    PREREQ_PM    => {
        'Moose'                   => '0',
	'MooseX::AbstractFactory' => '0',
	'MooseX::Singleton'       => '0',
        'Data::Dumper'            => '0',
	'Contextual::Return'      => '0',
	'DBIx::Class'             => '0',
	'LWP::UserAgent'          => '0',
	'JSON::RPC::Common'       => '0',
	'DateTime'                => '0',
	'DateTime::Precise'       => '0',
	'parent'                  => '0',
	'overload'                => '0',
    },                                               # e.g., Module::Name => 1.1
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT => 'Script interface to The Lacuna Expanse', 
	            #_FROM => 'lib/WWW/LacunaExpanse.pm',    # retrieve abstract from module
            AUTHOR => 'Ian Docherty <pause@icydee.com>'
          )
        : ()
    ),
);
