package Twittary::DB;
use strict;
use warnings; 

use YAML;
use DBI;

my($stmts) = YAML::Load( do{ local $/; <DATA> } );

our $Test = $ENV{TWITTER_TEST} ? "_$ENV{TWITTER_TEST}" : '';
my $config = {
    dsn  => "dbi:mysql:twitter$Test;host=127.0.0.1;port=3306",
    username => 'www',
    password => '',
};  

sub dsn { return $config }

sub dbh {
    my $class = shift;
    my $dsn = $class->dsn;
    return DBI->connect($dsn->{dsn}, $dsn->{username}, $dsn->{password});
}

sub init {
    die "too dangerous";
    my $admin_dbh = DBI->connect('dbi:mysql:mysql;host=127.0.0.1;port=3306', 'root', '')
        or die "cannot get admin dbh $DBI::errstr";
    for (@{ $stmts->{init} }) {
        # hack 
        s/twitter\b/twitter$Test/ if $Test;
        $admin_dbh->do($_);
    }
    $admin_dbh->disconnect;
}

sub load {
    my $self = shift;
    warn $config->{dsn};
    my $dbh = DBI->connect($config->{dsn}, $config->{username}, $config->{password})
        or die "cannot get dbh $DBI::errstr";
    for (@{ $stmts->{load} }) {
        warn $_;
        $dbh->do($_);
    }
    $dbh->disconnect;
}

1;

__DATA__
init:
    - DROP DATABASE IF EXISTS twitter
    - CREATE DATABASE IF NOT EXISTS twitter

load:
    - >
      CREATE TABLE IF NOT EXISTS tweet (
          user_id BIGINT UNSIGNED NOT NULL,
          tweet_id BIGINT UNSIGNED NOT NULL,
          text varchar(600) BINARY NOT NULL,
          created_at DATETIME,
          in_reply_to_status_id BIGINT UNSIGNED,
          in_reply_to_user_id BIGINT UNSIGNED,
          PRIMARY KEY (user_id, tweet_id),
          INDEX created_at_idx (created_at),
          INDEX (user_id, created_at)
      ) ENGINE=INNODB

    - >
      CREATE TABLE IF NOT EXISTS user (
          user_id BIGINT UNSIGNED PRIMARY KEY NOT NULL,
          name varchar(255) binary,
          locale varchar(8),
          timezone varchar(100),
          twitter_name varchar(255) binary,
          twitter_id bigint unsigned,
          last_fetched_on datetime,
          last_posted_on datetime,
          post_hour smallint,
          post_minute smallint,
          next_post_date datetime,
          endpoint_email varchar(255),
          endpoint_atom varchar(255) binary,
          endpoint_xmlrpc varchar(255) binary,
          endpoint_user varchar(255) binary,
          endpoint_pass varchar(255) binary,
          post_using_guest boolean default 0,
          post_title varchar(255) binary,
          post_prefix text binary,
          post_suffix text binary,
          last_post_failure_date datetime,
          post_failure_count mediumint,
          password varchar(100) binary,
          has_suspended boolean,
          preferred_posting_method varchar(100),
          email_verified boolean,
          email_challenge varchar(10),
          formatter_type varchar(20),
          format_hide_time boolean,
          format_hide_replies boolean,
          format_hide_status_link boolean,
          format_only_lifetweets boolean,
          no_fetch tinyint(1) default NULL,
          created_on datetime,
          INDEX (next_post_date, has_suspended)
      ) ENGINE=INNODB
    - >
      CREATE TABLE IF NOT EXISTS auth_token (
          token   varchar(255) binary not null,
          value   varchar(255) binary not null,
          user_id BIGINT UNSIGNED NOT NULL,
          PRIMARY KEY (token, value)
      ) ENGINE=INNODB
    - >
      CREATE TABLE IF NOT EXISTS hit (
          hit_on datetime,
          tweet_id bigint unsigned,
          user_id bigint unsigned,
          cookie bigint unsigned, 
          ip varchar(16),
          referrer varchar(1024)
      ) ENGINE=INNODB
