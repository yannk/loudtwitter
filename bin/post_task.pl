#! /usr/bin/perl -w
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';

use Getopt::Long;
use YAML;
use Twittary::Importer;
use Twittary::Core 'log' => 1;
use Twittary::Model::User;
use Twittary::Util;

our %PostErrors = (); # hash with recent post errors
our $Grace = 60 * 60 * 3;
our $DEBUG = 0;

my $log = Twittary::Core->log;

post_daily_tweets() while 1;

sub post_daily_tweets {
    my $now = Twittary::Util->now;
    my @users = Twittary::Model::User->search(
        { next_post_date => { op => '<=', value => $now },
          has_suspended  => { op => '!=', value => 1    },
        },
    );
    my %seen = ();
    for my $user (@users) {
        next if $seen{ $user->user_id }++; ## attempt to fix rodrigo ssue
        next if $user->has_suspended;
        next unless $user->can_post;
        my $error_time = $PostErrors{$user->user_id} || 0;
        my $grace = $Grace + int (rand(3600)); # randomize a bit
        unless (time - $error_time > $grace) {
            $log->debug("grace for " . $user->twitter_name);
            next;
        }
        eval {
            Twittary::Importer->user($user);
        };
        if ($@) {
            $log->error("error importing user before posting $@");
        }
        $log->info("working on " . $user->twitter_name);

        my $tweets = $user->daily_tweets || [];
        unless (@$tweets) {
            $log->info("Nothing to do for " .  $user->twitter_name . ", no tweets");
            $user->has_posted_on($user->next_post_date_obj, 1);
            next;
        }

        my $formatter = $user->formatter;
        my $content = eval { $formatter->process($tweets, $user->twitter_name, $user->post_prefix, $user->post_suffix) };
        if ($@) {
            if ($@ =~ /empty list/) {
                $log->error("only replies for " . $user->twitter_name);
                $user->has_posted_on($user->next_post_date_obj);
            } else {
                $log->fatal("Formatting died $@ for " . $user->twitter_name);
            }
            next;
        }
        #my $content = Twittary::Formatter->process($tweets, $user->twitter_name, $user->post_suffix);
        my $poster = $user->poster;
        eval {
            $poster->post(content => $content, title => $user->post_title);
            $user->has_posted_on($user->next_post_date_obj);
        }; if (my $err = $@) {
            $PostErrors{$user->user_id} = time; 
            chomp $err;
            $log->error("fail [$err] to post " . $user->twitter_name);
        } else {
            delete $PostErrors{$user->user_id};
            $log->info("just posted " . $user->twitter_name);
        }
    }
}

