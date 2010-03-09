#! /usr/bin/perl -w
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';

use Getopt::Long;
use Time::HiRes();
use DateTime;

use Gearman::Task;
use Gearman::Client;

use Twittary::DB;
use Twittary::Core;
use Twittary::Importer;
use Twittary::Core;

my $log    = Twittary::Core->log;
my $cfg    = Twittary::Core->config;
my $js     = [ $cfg->{GearmanServers} ];
my $client = Gearman::Client->new( job_servers => $js );

my %Locks;
my %opt;

GetOptions( 'no-sleep' => \$opt{no_sleep} );

my $bucket_size = 60 * 60; # every hour
my $bucket_max  = int( 24 * 3600 / $bucket_size ); 

my ($bucket) = get_current_bucket($bucket_size);
while (1) {
    $log->debug("Starting bucket $bucket");
    my $t0 = [ Time::HiRes::gettimeofday ];

    ## we do two selects in far less time than a bucket duration (in theory)
    my $posts  = select_users_for_bucket($bucket_size, $bucket);
    for my $user_id (@{ $posts }) {
        task('post', $user_id);
    }

    my $runtime = Time::HiRes::tv_interval($t0);
    my ($target, $remaining) = get_current_bucket($bucket_size);
    if ($target > $bucket) {
        $log->info(sprintf "Done in %.2f, posts: %d, switched bucket %d vs. %d",
                            $runtime, scalar @$posts, $target, $bucket);
    }
    else {
        $log->info(sprintf "Done in %.2f, posts: %d, sleeping for %ds",
                            $runtime, scalar @$posts, $remaining);
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
    $log->debug("B0 $bucket_0 - $seconds");
    my $bucket    = int($seconds / $size);
    my $remaining = $size - ($seconds % $size);
    return ($bucket, $remaining);
}

sub select_users_for_bucket {
    my ($bucket_size, $bucket) = @_;

    # rewind 24 buckets 
    my $begin_bucket = bucket_to_date( $bucket_size, $bucket - 25);
    my $end_bucket   = bucket_to_date( $bucket_size, $bucket -  1);

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
    $sth->execute($begin_bucket, $end_bucket);
    $log->debug("DATES: $begin_bucket, $end_bucket");
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

sub task {
    my $type    = shift;
    my $user_id = shift;
    my $task = Gearman::Task->new(
        $type,
        \Storable::nfreeze({
            user_id => $user_id,   
        }),
        {
            ## XXX i don't trust uniq implementation. Test
            #uniq => '-',
            uniq => "$type-$user_id",
        },
    );
    $client->dispatch_background($task);
}
