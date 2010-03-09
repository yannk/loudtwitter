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

my ($current_bucket) = get_current_bucket($bucket_size);
$log->debug("Starting bucket $current_bucket");

## we are scheduled to post in 3h from now
my $future_bucket = $current_bucket + 3600 * 3 / $bucket_size;

my $fetchs = select_users_btw_buckets($bucket_size, $current_bucket, $future_bucket);

my $fetch_count = scalar @$fetchs;
for my $user_id (@$fetchs) {
    Twittary::Jobs->background_task('fetch', $user_id, 'partial');
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

sub select_users_btw_buckets {
    my ($bucket_size, $bucket1, $bucket2) = @_;

    my $current_bucket = bucket_to_date( $bucket_size, $bucket1 );
    my $next_bucket    = bucket_to_date( $bucket_size, $bucket2 );

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
    my $fetch = [];
    while (my $row = $sth->fetch) {
        my ( $user_id, $post_date_str, $fetch_date_str, 
             $fail_date_str, $count ) = @$row;
        my $post_date  = $post_date_str
                         ? Twittary::Util->mysql_to_dt($post_date_str)
                         : undef;
        my $fetch_date = $fetch_date_str
                         ? Twittary::Util->mysql_to_dt($fetch_date_str)
                         : undef;

        push @$fetch, $user_id;
    }
    my $runtime = Time::HiRes::tv_interval($t0);
    $log->info(sprintf "Selected in %.2f", $runtime);
    return $fetch;
}
