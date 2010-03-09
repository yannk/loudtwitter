#!/usr/bin/perl
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';
use DBI;
use Getopt::Long;
use Twittary::DB;
use Twittary::Core;
use Date::Manip;

my %opt;
GetOptions(
    "dry-run"         => \$opt{dry_run},
    "since=s"         => \$opt{since},
);

$opt{dry_run} = 1;
my $since = UnixDate(ParseDate($opt{since}), "%s");
unless ($since) {
    warn "Couldn't parse $opt{since}, rewinding 30 days instead" if $opt{since};
    $since = (time - 86400 * 30);
}

my $src   = "tweet";
my $dst   = "tweet_archive";
my $conf  = Twittary::DB->dsn; 
my $dbh   = DBI->connect($conf->{dsn}, $conf->{user}, $conf->{pass})
    or die "cannot connect to $conf->{dsn}";

#$dbh->{mysql_use_result} = 1;
## TODO, wrap in a transaction

my $sth = $dbh->prepare("SELECT * FROM $src WHERE created_at < FROM_UNIXTIME(?)")
    or die $dbh->errstr;

$sth->execute($since);

my @cols;
my $coln = $sth->{'NUM_OF_FIELDS'} || 0;
push @cols, $sth->{NAME}[$_] for (0 .. ($coln - 1));

my $ins_sql = "INSERT INTO $dst (" . join(', ', @cols) . ") values ";

while( my $rows = $sth->fetchall_arrayref(undef, 2_000) ) {
    copy($ins_sql, $rows, \@cols);
}
delete_rows($dbh, $since, $src);

sub copy {
    my $ins  = shift;
    my $rows = shift;
    my $cols = shift;
    my $row_ph = "(" . join (", ", ('?') x scalar @cols) . ")";
    my $placeholders = join ( ", ", ($row_ph) x scalar @$rows);
    my $final = $ins . "($placeholders)";
    if ($opt{dry_run}) {
        my $n = scalar @$rows;
        Twittary::Core->log->info("Would copy $n rows in @$cols: $final");
        return;
    }
}

sub delete_rows {
    my ($dbh, $since, $table) = @_;
    my $sql = "DELETE FROM $table WHERE created_at < FROM_UNIXTIME($since) LIMIT 2000";
    my $sth = $dbh->prepare( $sql );
    if ($opt{dry_run}) {
        Twittary::Core->log->info("Would delete using $sql");
        return;
    }
    return;
    do {
        $sth->execute;
        Twittary::Core->log->debug("DELETED " . ( $sth->rows || "~"). " from $table");
    } while ($sth->rows);
}

