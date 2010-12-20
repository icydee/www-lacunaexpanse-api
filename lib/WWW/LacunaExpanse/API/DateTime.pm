package WWW::LacunaExpanse::API::DateTime;

use strict;
use warnings;

use DateTime::Precise;

# Given a Lacuna Expanse date-time string, return a DateTime object

use parent qw(DateTime::Precise);

#
# parse a Laguna Expanse date time into a DateTime object
#
sub from_lacuna_string {
    my ($class, $date_str) = @_;

    my ($day,$month,$year,$hour,$minute,$second,$timezone) = $date_str =~
        m/^(\d\d) (\d\d) (\d\d\d\d) (\d\d):(\d\d):(\d\d) (.*)$/;

    my $dt = DateTime::Precise->new("$year.$month.$day $hour:$minute:$second");

    if ($dt) {
        # bless it into this class
        my $self = bless $dt, $class;
        return $self;
    }
    return;
}



1;
