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

#    print "DateTime: [$date_str]\n";
    my ($year,$month,$day,$hour,$minute,$second) = $date_str =~
        m{(\d\d\d\d)/?(\d\d)/?(\d\d)\s?(\d\d):?(\d\d):?(\d{1,2}?)};

    my $dt = DateTime::Precise->new("$year.$month.$day $hour:$minute:$second");

    if ($dt) {
        # bless it into this class
        my $self = bless $dt, $class;
        return $self;
    }
    return;
}


#
# Format seconds as days, hours, minutes and seconds
#
sub format_seconds {
    my ($class, $period) = @_;

    my $seconds     = $period % 60;
    $period        -= $seconds;
    $period        /= 60;

    my $minutes     = $period % 60;
    $period        -= $minutes;
    $period        /= 60;

    my $hours       = $period % 60;
    $period        -= $hours;
    $period        /= 24;

    my $days        = $period;
    my $str = '';
    my $blank_lead  = 1;
    my $blank_tail  = 0;

    if ($days) {
        $str .= "$days ".($days == 1 ? 'day' : 'days').' ';
        $blank_lead = 0;
        $blank_tail = 1 if $hours == 0 && $minutes == 0 && $seconds == 0;
    }
    if ($hours || (! $blank_lead && ! $blank_tail)) {
        $str .= "$hours ".($hours == 1 ? 'hour' : 'hours').' ';
        $blank_lead = 0;
        $blank_tail = 1 if $minutes == 0 && $seconds == 0;
    }
    if ($minutes || (! $blank_lead && ! $blank_tail)) {
        $str .= "$minutes ".($minutes == 1 ? 'minute' : 'minutes').' ';
        $blank_lead = 0;
    }
    if (! $blank_tail) {
        $str .= "$seconds ".($seconds == 1 ? 'second' : 'seconds').' ';
    }
    return $str;
}

1;
