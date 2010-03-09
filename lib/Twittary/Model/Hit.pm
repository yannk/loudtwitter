package Twittary::Model::Hit;

use strict;
use warnings;
use base qw( Data::ObjectDriver::BaseObject );

__PACKAGE__->install_properties({
    columns => [
        'hit_on', 'tweet_id', 'user_id', 'cookie', 'ip', 'referrer',
    ],
    datasource  => 'hit',
    driver      => Twittary::TweetDriver->driver,
});

sub tracker {
    my $class = shift;
    my ($user, $tweets) = @_;
    my $twitter_name = $user->twitter_name;
    return "" unless $twitter_name;
#    return "" unless $twitter_name =~ /^(yannk|tenia)$/;
    return "" unless $tweets && @$tweets;
    my $user_id = $user->user_id;
    my $tweet_id = $tweets->[0]->tweet_id;
    my $uri = qq{http://$tweet_id.data.loudtwitter.com/$user_id};
    return qq{<img src="$uri" width="1" height="1" border="0" />};
}

1;
