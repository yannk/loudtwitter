#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';
use Twittary::Model::User;

my $user = Twittary::Model::User->lookup(shift);
my $n = scalar @{ $user->daily_tweets };

my $auth = 
    join ", ", map { $_->value } Twittary::Model::AuthToken->search({
        user_id => $user->user_id
    });

no warnings;
print <<EOP;
shid: ${ \$user->shid }
post date: ${ \$user->post_hour }:${ \$user->post_minute } ${ \$user->timezone }
twitter_name: ${ \$user->twitter_name }
suspended: ${ \$user->has_suspended }
can_post: ${ \$user->can_post } - email_verified: ${ \$user->email_verified } no fetch: ${ \$user->no_fetch }
ppm: ${ \$user->preferred_posting_method }
email: ${ \$user->email }
password: ${ \$user->password }
next_post_date: ${ \$user->next_post_date } ${ \$user->eta_before_next } local(${ \$user->next_post_date_local })
today's tweet: $n
auth: $auth
last_fetched: ${ \$user->last_fetched_on_http_date }
post failures: ${ \$user->post_failure_count }
created_on: ${ \$user->created_on }
endpoint_atom: ${ \$user->endpoint_atom }
endpoint_xmlrpc: ${ \$user->endpoint_xmlrpc }
endpoint_email: ${ \$user->endpoint_email }
EOP


