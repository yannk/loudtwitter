#! /usr/bin/perl -w
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../dev-local-lib";
use Test::More tests => 3;

use_ok 'Twittary::TweetDriver';

my $id1 = Twittary::TweetDriver->new_id;
like $id1, qr/^\d+$/, "can generate ids";
my $id2 = Twittary::TweetDriver->new_id;

cmp_ok $id2, '>', $id1, "id2 is higher than id1";
