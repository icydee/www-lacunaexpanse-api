package WWW::LacunaExpanse::API::DateTime;

use strict;
use warnings;

use DateTime;

# Given a Lacuna Expanse date-time string, return a DateTime object

use parent qw(DateTime::Precise);

sub now {
    my ($class) = @_;

    my $now = DateTime->now;
    return $class->new($now->ymd('.').' '.$now->hms(':'));
}

# Stringify
use overload '""' => sub {
    my $date = $_[0];

    my $year    = $date->year;
    my $month   = $date->month;
    my $day     = $date->day;
    my $hour    = $date->hours;
    my $minute  = $date->minutes;
    my $second  = $date->seconds;

    my $str = "$year/$month/$day $hour:$minute:$second";

    return $str;
};

#
# parse a Laguna Expanse date time into a DateTime object
#
sub from_lacuna_string {
    my ($class, $date_str) = @_;

    if ( ! $date_str) {
        return DateTime::Precise->new("0000.00.00 00:00:00");
    }

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

#
# parse a Laguna Expanse email message date time into a DateTime object
#
sub from_lacuna_email_string {
    my ($class, $date_str) = @_;

    my ($year,$month,$day,$hour,$minute,$second) = $date_str =~
        m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;

    my $dt = DateTime::Precise->new("$year.$month.$day $hour:$minute:$second");

    if ($dt) {
        # bless it into this class
        my $self = bless $dt, $class;
        return $self;
    }
    return;
}


1;
