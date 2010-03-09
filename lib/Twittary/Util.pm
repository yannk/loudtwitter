package Twittary::Util;
use strict;
use warnings;

use DateTime;
use DateTime::Format::HTTP;
use DateTime::Format::Twitter;
use DateTime::Format::MySQL;

sub twitter_to_dt {
    my $class = shift;
    my $date = shift;
    return DateTime::Format::Twitter->parse_datetime($date);
}

sub tw_to_mysql {
    my $class = shift;
    my $date = shift;
    return $class->dt_to_mysql($class->twitter_to_dt($date));
}

sub dt_to_mysql {
    my $class = shift;
    my $dt = shift;
    $dt->set_time_zone('UTC');
    return $dt->ymd('-') . ' ' . $dt->hms(':');
}

sub now {
    my $class = shift;
    return $class->dt_to_mysql(DateTime->now);
}

sub yesterday {
    my $class = shift;
    return $class->dt_to_mysql(DateTime->now->subtract( days => 1 ));
}

sub mysql_to_dt {
    my $class = shift;
    my $mysql = shift;
    my $date = DateTime::Format::MySQL->parse_datetime($mysql);
    if ($date->time_zone->is_floating) {
        $date->set_time_zone('UTC');
    }
    return $date;
}

sub mysql_to_http {
    my $class = shift;
    my $mysql = shift;
    my $dt = $class->mysql_to_dt($mysql);
    return DateTime::Format::HTTP->format_datetime($dt);
}


1;
