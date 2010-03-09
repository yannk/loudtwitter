#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';
use Twittary::Fetcher;
use YAML;

use Getopt::Long;
my %opts;
GetOptions(
    "twitter_name=s" => \$opts{twitter_name},
    "since=s"        => \$opts{since},
    "count=i"        => \$opts{count},
    "since_id=i"     => \$opts{since_id},
    "continue"       => \$opts{continue},
    "field=s"        => \$opts{field},
);

my $tweets = Twittary::Fetcher->get_since(%opts);
if ($opts{field}) {
    print "$_\n" for map { $_->{ $opts{field} } } @$tweets;
}
else {
    print Dump $tweets;
}
