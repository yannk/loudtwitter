#!/usr/bin/perl -w
use strict;
use warnings;

use Find::Lib '../lib' => 'Twittary::Bootstrap';
use Gearman::Worker;
use Twittary::Core;
use Twittary::Jobs;
use Getopt::Long;

my %opts;
GetOptions(
    'ability=s@' => \$opts{abilities},
);

my $config = Twittary::Core->config;
my $log    = Twittary::Core->log;
my $worker = Gearman::Worker->new;
$worker->job_servers(@{ $config->{GearmanServers} });
my @ability = ();
for (@{ $opts{abilities} }) {
    unless (Twittary::Jobs->can($_)) {
        $log->error("ignoring unknown job: $_");
        next;
    }
    push @ability, $_;
}
for my $ab (@ability) {
    $worker->register_function( $ab => sub { Twittary::Jobs->do_job($ab, @_) });
}
$worker->work while 1;

