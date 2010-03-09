package Twittary::Model::Tweet;
use strict;
use warnings;

#use base qw/Twittary::Object/;
use base qw( Data::ObjectDriver::BaseObject );
use Twittary::TweetDriver;
use Twittary::Util;

__PACKAGE__->install_properties({
    columns => [
        'user_id', 'tweet_id', 'created_at', 'text',
        'in_reply_to_status_id', 'in_reply_to_user_id',
    ],
    datasource  => 'tweet',
    primary_key => ['user_id', 'tweet_id'],
    driver      => Twittary::TweetDriver->driver,
});

sub user {
    my $tweet = shift;
    ## cache in object
    my $user = Twittary::Model::User->lookup($tweet->user_id);
    return $user;
}

sub last_20_of {
    my $tweet = shift;
    my $user_id = shift;
    my @res = $tweet->search({
        user_id => $user_id,
    }, { limit => 20, sort => 'created_at', direction => 'descend' });
    return \@res;
}

sub import_tweet {
    my $class = shift;
    my $user_id = shift;
    my $data = shift;
    my $tweet = $class->new;
    $tweet->user_id($user_id);
    $tweet->tweet_id($data->{id});
    $tweet->created_at(Twittary::Util->tw_to_mysql($data->{created_at}));
    $tweet->text($data->{text});
    $tweet->in_reply_to_user_id($data->{in_reply_to_user_id});
    $tweet->in_reply_to_status_id($data->{in_reply_to_status_id});
    $tweet->replace;
    return $tweet;
}

sub is_reply {
    my $tweet = shift;
    return 1 if $tweet->in_reply_to_user_id || $tweet->in_reply_to_status_id;
    return 0;
}

my $lt_regex = qr{
        \#                                         # the hash aka channel
        (lt | life[-_]?tweet   | loud[-_]?tweet    # the different ways of
            | loud[-_]?twitter | loud[-_]?tweeter  # specifying a lifetweet
        )\b
}xms;

my $noise_regex = qr{#noise}ims;

sub lt_regex { $lt_regex }

sub is_lifetweet {
    my $tweet = shift;
    my $text = $tweet->text or return 0;
    return $text =~ $lt_regex ? 1 : 0;
}

sub is_noise {
    my $tweet = shift;
    my $text = $tweet->text or return 0;
    return $text =~ $noise_regex ? 1 : 0;
}

sub created_at_obj {
    my $tweet = shift;
    unless (exists $tweet->{__created_at_obj}) {
        my $at = $tweet->created_at;
        return unless $at;
        $tweet->{__created_at_obj} = Twittary::Util->mysql_to_dt($at);
        my $tz = $tweet->user ? $tweet->user->timezone : undef;
        if ($tz) {
            eval {
                $tweet->{__created_at_obj}->set_time_zone($tz);
            };
        }
    }
    return $tweet->{__created_at_obj};
}
1;
