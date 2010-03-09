#! /usr/bin/perl -w
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';
use Test::More tests => 6;

use_ok 'Twittary::DB';
use_ok 'Twittary::Model::User';

init();

END {
    teardown();
}

my $user = Twittary::Model::User->new;
$user->twitter_name('test');
ok $user->save;

ok $user->user_id;
$user = Twittary::Model::User->lookup($user->user_id);
ok $user;
is $user->twitter_name, 'test';

sub init {
    $Twittary::DB::Test="_test";
    Twittary::DB->init;
    Twittary::DB->load;
}

sub teardown {
    Twittary::DB->init;
}
