#! /usr/bin/perl -w
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';

use Getopt::Long;
use YAML;
use Twittary::Importer;
use Twittary::Core 'log' => 1;
my $log = Twittary::Core->log;

fetch_all_tweets(\@ARGV) while 1;

sub fetch_all_tweets {
    my $args = shift;
    eval {
        Twittary::Importer->all_users(@{ $args || [] });
    }; if ($@) {
        $log->error("Error in import $@");
    }
}


