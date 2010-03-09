#! /usr/bin/perl -w
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';

use DateTime;

use Twittary::DB;
use Twittary::Model::User;
use Twittary::Util;
use Twittary::Core;

my $log = Twittary::Core->log;
my $dbh = Twittary::DB->dbh;

my $SQL = <<EOSQL;
SELECT user_id
  FROM user
 WHERE next_post_date  < DATE_SUB(NOW(), interval 6 hour) 
   AND next_post_date >= '2009-08-01' 
   AND (has_suspended  = 0 or has_suspended IS NULL)
EOSQL

my $sth = $dbh->prepare_cached($SQL)
or die $dbh->errstr;
my $users = [];
$sth->execute;
while (my $row = $sth->fetch) {
    my $user_id = $row->[0];
    push @$users, $user_id;

}

my $now = DateTime->now;
## slow, but better than my raw sql skills
while (my $user_id = shift @$users) {
    my $user = Twittary::Model::User->lookup($user_id)
        or next;
    
    my $before = $user->next_post_date_obj;
    $user->adjust_post_time;
    $log->info(sprintf "%s %s => %s\n",
	 $user_id, $before->iso8601, $user->next_post_date_obj->iso8601,
    );
    next;
    my $date = $user->next_post_date_obj;
    my $stale = $date->clone;
    $date->set_month( $now->month );
    $date->set_year( $now->year );
    $date->set_day( $now->day );
    $date->set_hour( $stale->hour );
    $date->set_minute( $stale->minute );
    if ($date < $now) {
        $date->add(days => 1);
        die "What?" unless $date >= $now;
    }
    $log->info(sprintf "%s %s => %s\n",
	 $user_id, $stale->iso8601, $date->iso8601,
    );
    $user->next_post_date( Twittary::Util->dt_to_mysql($date) );
    $user->update;
}

