#! /usr/bin/perl -w
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';
use Find::Lib 'lib';
use local::lib;
use Test::More tests => 9;

use Twittary::Core;
use DateTime;

use Fake::Tweet;
use_ok 'Twittary::Formatter::Title';

my $date = DateTime->new(
    year => 2009,
    month => 9,
    day => 7,
    hour => 19,
    minute => 13,
);

my $cfg = {
    number_of_tweets  => 6,
    post_date         => $date,
    number_of_replies => 2,
};

sub fmt {
    my $format = shift;
    my $out = Twittary::Formatter::Title->format($cfg, $format);
    return $out;
}

is fmt(""), "";
is fmt("'hello'"), "hello";
is fmt("'My %NT tweets of the day (with %NR replies...)'"),
       "My 6 tweets of the day (with 2 replies...)",
   "our own formatters";

is fmt("'My %NT tweets this 'EEEE"),
       "My 6 tweets this Monday",
   "use CLDR formats";

is fmt("[yyyy] 'My %NT tweets this 'eeee"),
       "[2009] My 6 tweets this Monday",
   "use CLDR formats";

is fmt("My %NT tweets of the day (with %NR replies...)"),
       "92009 6 t3702t0 of t72 7PM2009 (37it7 2 r2pli20...)",
   "If user doesn't use escaper it leads to weird things";

## quotes
is fmt("EEEE'''s tweets'"),
       "Monday's tweets",
   "Formatting quotes";

## Check locale
$cfg->{post_date}->set_locale('fr_FR');
is fmt("'Mes %NT tweets de 'EEEE' (comportant %NR reponses)'"),
        "Mes 6 tweets de lundi (comportant 2 reponses)",
   "localisation";
