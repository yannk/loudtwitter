#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';
use Twittary::Model::User;
my @res;
my $what = shift;

my @tokens = Twittary::Model::AuthToken->search({
    value => \"LIKE '\%$what\%'"
});
push @res, @tokens if @tokens;
my @users = Twittary::Model::User->search({
    twitter_name => \"LIKE '\%$what\%' collate latin1_swedish_ci" 
});

push @res, @users if @users;
use YAML;
warn Dump \@res;
