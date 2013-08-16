package WWW::LacunaExpanse::API::Bits::DateTime;

use strict;
use warnings;

use DateTime;

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

    my $str = "$year $month $day $hour:$minute:$second";

    return $str;
};

sub new_from_raw {
    my ($class, $raw) = @_;

    my ($day,$month,$year,$hour,$minute,$second,$timezone) = $raw =~
        m/^(\d\d) (\d\d) (\d\d\d\d) (\d\d):(\d\d):(\d\d) (.*)$/;
    my $dt;

    if (defined $day) {
        $dt = DateTime::Precise->new("$year.$month.$day $hour:$minute:$second");
    }
    else {
        $dt = DateTime::Precise->new("0000.00.00 00:00:00");
    }
    # bless it into this class
    my $self = bless $dt, $class;
    return $self;
}

1;
