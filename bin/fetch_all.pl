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

my $dbh = Twittary::DB->dbh;

my $SQL = <<EOSQL;
SELECT user_id,
    next_post_date,
    last_fetched_on,
    last_post_failure_date,
    post_failure_count
FROM user
WHERE (has_suspended  = 0 or has_suspended IS NULL)
EOSQL

my $sth = $dbh->prepare_cached($SQL)
    or die $dbh->errstr;
$sth->execute();
my $post = [];
while (my $row = $sth->fetch) {
    my ( $user_id, $post_date_str, $fetch_date_str,
            $fail_date_str, $count ) = @$row;
    Twittary::Jobs->background_task('fetch', $user_id, 'partial');
}
