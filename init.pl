#! /usr/bin/perl
use strict;
use warnings;
use lib 'lib';

use Twittary::DB;
die "careful " unless shift eq 'yes';

Twittary::DB->init;
Twittary::DB->load;
print "init done\n";
