#!/usr/bin/perl -w
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';

use Twittary::Fetcher;

use YAML;
warn Dump (Twittary::Fetcher->verify_twitter_name(shift));
