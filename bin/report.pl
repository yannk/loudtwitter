#!/usr/bin/perl
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';
use Twittary::Model::User;
use DateTime;

my $report_date = DateTime->now->subtract(days => 1);
my @users = Twittary::Model::User->search({ created_on => { op => '>', value => $report_date }});
printf STDOUT "COUNT: %d\n\n", scalar @users;
for (@users) {
    my $endpoint = $_->endpoint_atom || $_->endpoint_email || $_->endpoint_xmlrpc;
    my $method = "[" . (join ", ", map { $_->token }
                 Twittary::Model::AuthToken->search({ user_id => $_->user_id }))
               . "]";
    my $status = $_->can_post ? $_->post_failure_count ? "FAIL" : "GOOD" 
                 : "CANTPOST";
    printf STDOUT "%s name=%s %s %s %s\n", map { $_ || "-" }
                   $_->twitter_name, $_->name, $endpoint, $method, $status;
}
