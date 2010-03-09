package Fake::Tweet;
use strict;
use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw/tweet_id text created_at user in_reply_to_status_id in_reply_to_user_id/);

use Twittary::Model::Tweet;

*created_at_obj = \&Twittary::Model::Tweet::created_at_obj;
*is_reply       = \&Twittary::Model::Tweet::is_reply;
*is_lifetweet   = \&Twittary::Model::Tweet::is_lifetweet;
*is_noise       = \&Twittary::Model::Tweet::is_noise;
*lt_regex       = \&Twittary::Model::Tweet::lt_regex;

1;

