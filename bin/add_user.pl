#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';
use Twittary::Model::User;

my $openid_uri = shift || die "specify an url";
my $twitter_name = shift || "loiclemeur";

my $user = Twittary::Model::User->new;

$user->openid_uri($openid_uri);
$user->twitter_name($twitter_name);
$user->post_hour('18');
$user->post_minute(0);
$user->save;
print STDERR $user->user_id . "\n";
