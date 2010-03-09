package Twittary::Importer;
use strict;
use warnings;

use Twittary::Importer;
use Twittary::Model::Tweet;
use Twittary::Model::User;
use Twittary::Fetcher;
use Twittary::Util;
use Twittary::Core;
use Data::Visitor::Callback();
use HTML::Entities();
use YAML;

my $v = Data::Visitor::Callback->new(
    value => sub {
        my ($visitor, $data) = @_;
        $data = HTML::Entities::decode($data) if $data;
        return $data;
    }
);

sub user {
    my $class = shift;
    my $user  = shift;

    my $twitter_id = $user->twitter_id;
    unless ($twitter_id) {
        ## Lazily repopulate
        my $name = $user->twitter_name;
        return unless $name;
        $twitter_id = Twittary::Fetcher->verify_twitter_name($name);
        return unless $twitter_id && $twitter_id > 0;
        $user->twitter_id($twitter_id);
        $user->update;
    }
    my $tweets = $user->last_20 || [];
    my %known = map { $_->tweet_id => 1 } @$tweets;

    my $since = $user->last_fetched_on_http_date;
    my $fresh_tweets = Twittary::Fetcher->get_since(
        twitter_id => $twitter_id,
        since => $since,
    );

    unless ($fresh_tweets) {
        warn "no fresh since $since" if $Twittary::DEBUG;
        return;
    } else {
        warn "got fresh sice $since" if $Twittary::DEBUG;
    }

    my @new_tweets = grep { ! $known{$_->{id}} } @$fresh_tweets;
    if ($Twittary::DEBUG) {
        warn Dump {
            fresh => $fresh_tweets,
            known => \%known,
            new   => \@new_tweets
        };
    }
    my $latest = undef;
    for (@new_tweets) {
        $class->decode_entities($_); 
        my $tweet = $user->import_tweet($_);
        if ($latest) {
            $latest = $tweet->created_at_obj
                if $tweet->created_at_obj > $latest;
        }
        else {
            $latest = $tweet->created_at_obj;
        }
    }
    ## There is a bug here XXX
    ## (we should really compute the latest based on @$fresh_tweets
    ## just in case the last_fetched_on is older that one known tweet (ok, that
    ## shouldn't happen)) because otherwise we'll fetch again and over again
    ## the same old tweet until a newer arrive.
    if ($latest) {
        $user->last_fetched_on(Twittary::Util->dt_to_mysql($latest));
        $user->save;
    }
}

sub missing {
    my $class       = shift;
    my $user        = shift;
    my $no_continue = shift;

    my $log = Twittary::Core->log;

    my $twitter_id = $user->twitter_id;
    unless ($twitter_id) {
        ## Lazily repopulate
        my $name = $user->twitter_name;
        unless ($name) {
            $log->warn("twitter name is missing for ". $user->user_id);
            return;
        }
        $twitter_id = Twittary::Fetcher->verify_twitter_name($name);
        return unless $twitter_id && $twitter_id > 0;
        $user->twitter_id($twitter_id);
        $user->update;
    }

    my %since = ();
    my $last_tweet = $user->last_tweet;
    if ($last_tweet) {
        $since{since_id} = $last_tweet->tweet_id;
    }
    elsif (my $last_date = $user->last_fetched_on_http_date ) {
        $since{since} = $last_date;
    }

    my $fresh_tweets = Twittary::Fetcher->get_since(
        twitter_id => $twitter_id,
        continue   => ! $no_continue,
        %since,
    );
    my $how_many = scalar @$fresh_tweets;
    if ($how_many) {
        $log->info("Fetched $how_many");
    }
    else {
        $log->info("No new tweets for ". $user->twitter_name);
    }

    my $latest = undef;
    for (@$fresh_tweets) {
        $class->decode_entities($_); 
        my $tweet = $user->import_tweet($_);
        if ($latest) {
            $latest = $tweet->created_at_obj
                if $tweet->created_at_obj > $latest;
        }
        else {
            $latest = $tweet->created_at_obj;
        }
    }
    $user->last_fetched_on(
        Twittary::Util->dt_to_mysql($latest || DateTime->now)
    );
    $user->update;
    return 1;
}

sub decode_entities {
    my $class = shift;
    my($data) = @_;
    $v->visit( $data );
}

## for now that should do it
sub all_users {
    my $class = shift; 
    my $idx   = shift || 0;
    my $skip  = shift || 1;
    
    my @users = Twittary::Model::User->search();
    for (my $i = $idx; $i < scalar @users; $i += $skip) {
        next if $users[$i]->no_fetch;
        my $user_id = $users[$i]->user_id;
        my $twitter_name = $users[$i]->twitter_name || "<>";
        Twittary::Core->log->debug("fetching $twitter_name $user_id");
        eval { $class->user($users[$i]) };
        if (my $err = $@) {
            $err =~ s/\n//gsm;
            Twittary::Core->log->error("Importing $twitter_name $user_id [$err]");
        }
    }
}

1;
