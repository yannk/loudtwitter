#! /usr/bin/perl -w
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';

use Getopt::Long;
use Time::HiRes();
use DateTime;

use Twittary::DB;
use Twittary::Core;
use Twittary::Importer;
use Twittary::Core;
use Twittary::Jobs;

my %Locks;
my %opt;

GetOptions( 'no-sleep' => \$opt{no_sleep} );

my $log         = Twittary::Core->log;
my $bucket_size = 5 * 60; # 5mn bucket size
my $bucket_max  = int( 24 * 3600 / $bucket_size ); 
my $lock_time   = $bucket_size;

unless ($opt{no_sleep}) {
    $log->info("Sleeping for $lock_time...");
    sleep $lock_time;
    $log->info("... Done.");
}

my ($bucket) = get_current_bucket($bucket_size);
while (1) {
    $log->debug("Starting bucket $bucket");
    my $t0 = [ Time::HiRes::gettimeofday ];

    ## we are scheduled to post in 6h from now
    my $future_bucket = $bucket + 3600 * 6 / $bucket_size;

    ## we do two selects in far less time than a bucket duration (in theory)
    my $fetchs = select_users_in_bucket($bucket_size, $future_bucket);
    my $posts  = select_users_in_bucket($bucket_size, $bucket);
    my $post_count  = scalar @$posts;
    my $fetch_count = scalar @$fetchs;
    for my $user_id (@{ $posts }) {
        ## annoying on fresh restart... how can I know since I 
        ## lost %Locks?
        next if is_locked($user_id);
        lock_user($user_id);
        Twittary::Jobs->background_task('post', $user_id);
    }
    for my $user_id (@$fetchs) {
        Twittary::Jobs->background_task('fetch', $user_id);
    }

    ## verify bucket drift, change bucket
    my $runtime = Time::HiRes::tv_interval($t0);
    my ($target, $remaining) = get_current_bucket($bucket_size);
    if ($target > $bucket) {
        $log->info(sprintf "Done in %.2f, posts: %d, fetchs: %d, switched bucket %d vs. %d",
                            $runtime, $post_count, $fetch_count, $target, $bucket);
    }
    else {
        $log->info(sprintf "Done in %.2f, posts: %d, fetchs: %d, sleeping for %ds",
                            $runtime, $post_count, $fetch_count, $remaining);
        sleep $remaining;
    }

    ## next bucket
    $bucket = ++$bucket % $bucket_max;
}

sub bucket_to_date {
    my $size      = shift;
    my $bucket    = shift;
    my $bucket_0  = DateTime->now->truncate(to => 'day');
    $bucket_0->add( seconds => $bucket * $size);
    return Twittary::Util->dt_to_mysql($bucket_0);
}

sub get_current_bucket {
    my $size = shift;
    my $now  = DateTime->now;

    my $bucket_0  = $now->clone->truncate(to => 'day');
    my $delta     = $now->clone->subtract_datetime_absolute( $bucket_0 ); 
    my $seconds   = $delta->in_units('seconds');
    my $bucket    = int($seconds / $size);
    my $remaining = $size - $seconds % $size;
    return ($bucket, $remaining);
}

sub lock_user {
    my $user_id = shift;
    $Locks{$user_id} = time();
}

sub is_locked {
    my $user_id = shift;
    my $lock = $Locks{$user_id};
    return unless $lock;
    if (time - $lock > $lock_time) {
        $log->debug("Unlocking $user_id");
        delete $Locks{$user_id};
        return;
    }
    $log->debug("$user_id is locked");
    return 1;
}

sub select_users_in_bucket {
    my ($bucket_size, $bucket) = @_;

    my $current_bucket = bucket_to_date( $bucket_size, $bucket );
    my $next_bucket    = bucket_to_date( $bucket_size, $bucket + 1);

    my $t0  = [ Time::HiRes::gettimeofday ];
    my $now = DateTime->now;
    my $dbh = Twittary::DB->dbh;

    my $SQL = <<EOSQL;
SELECT user_id,
       next_post_date,
       last_fetched_on,
       last_post_failure_date,
       post_failure_count
  FROM user
 WHERE next_post_date >= ?
   AND next_post_date  < ? 
   AND (has_suspended  = 0 or has_suspended IS NULL)
EOSQL
    
    my $sth = $dbh->prepare_cached($SQL)
        or die $dbh->errstr;
    $sth->execute($current_bucket, $next_bucket);
    $log->debug("DATES: $current_bucket, $next_bucket");
    my $post = [];
    while (my $row = $sth->fetch) {
        my ( $user_id, $post_date_str, $fetch_date_str, 
             $fail_date_str, $count ) = @$row;
        my $post_date  = $post_date_str
                         ? Twittary::Util->mysql_to_dt($post_date_str)
                         : undef;
        my $fetch_date = $fetch_date_str
                         ? Twittary::Util->mysql_to_dt($fetch_date_str)
                         : undef;

        ## now determine user_id to post, exclude failing users
        if ($fail_date_str) {
            # XXX reset this fields on successful posting
            my $fail_date = Twittary::Util->mysql_to_dt($fail_date_str);
            my $quarantine = DateTime::Duration->new( seconds => 2 ** $count );
            next unless $fail_date->clone->add_duration($quarantine) < $now;
        }
        push @$post, $user_id;
    }
    my $runtime = Time::HiRes::tv_interval($t0);
    $log->info(sprintf "Selected in %.2f", $runtime);
    return $post;
}

sub is_in {
    my $date1 = shift;
    my $date2 = shift;
    my $mn    = shift;
    return 0 unless $date2;
    $date1->clone->subtract( minutes => $mn );
    #return DateTime->compare($date1, $date2) > 0 ? 0 : 1;
    return $date1 < $date2;
}
