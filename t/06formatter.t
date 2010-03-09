#! /usr/bin/perl -w
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';
use Find::Lib 'lib';
use local::lib;
use Test::More tests => 38;

use Twittary::Util;

use Twittary::Core;

Twittary::Core->log->info("test");
use Fake::Tweet;
use_ok 'Twittary::Formatter::List';
use_ok 'Twittary::Formatter::Paragraph';
my($r, $t, $text, $res);

*Fake::User::timezone = sub { return 'Europe/Paris' };

my $user = bless {}, "Fake::User"; 
my $td = { tweet_id =>  1, text => 'thetext', 
           created_at => '2007-05-03 10:00:00', user => $user };

$t = Fake::Tweet->new($td);
ok !$t->is_noise;
ok !$t->is_lifetweet;
my $f = Twittary::Formatter::List->new;

## html struct text
$r = $f->process([ $t ], "toto");
like $r, qr/ul class="loudtwitter"/, "class";
like $r, qr/12:00/, "hour & timezone ok";

$r = $f->format_tweet($t, "toto");
like $r, qr/thetext/, "text is present, of course";
like $r, qr/1">#</, "status is linked";

my $f2 = Twittary::Formatter::Paragraph->new({ 
    options => { hide_status_link => 1, hide_time => 1, hide_replies => 1 },
});

my $fake_reply = Fake::Tweet->new($td);
$fake_reply->text('@reply this is a FAKE reply #lifetweet #loudtweet');
ok $fake_reply->is_lifetweet;
ok !$t->is_lifetweet;
my $real_reply = Fake::Tweet->new($td);
$real_reply->text('this one is real! in #lt');
$real_reply->in_reply_to_status_id(1214);
ok $real_reply->is_lifetweet, "real_reply is a lifetweet";

my $real_reply2 = Fake::Tweet->new($td);
$real_reply2->text('this one is real too');
$real_reply2->in_reply_to_user_id(1214);
ok !$real_reply2->is_lifetweet;

my $noise1 = Fake::Tweet->new($td);
$noise1->text('lot of  #Noise #somethingelse');
$noise1->in_reply_to_user_id(1214);
ok !$noise1->is_lifetweet;
ok  $noise1->is_noise;

my $noise2 = Fake::Tweet->new($td);
$noise2->text('this is noise #noise #lt');
ok  $noise2->is_lifetweet;
ok  $noise2->is_noise;
my $alltweets = [ $t, $fake_reply, $real_reply, $real_reply2, $noise1, $noise2 ];
$r = $f2->process([ @$alltweets ], "toto");
diag $r;

  like $r, qr/<p class="loudtwitter">/, "class on p";
unlike $r, qr/12:00/, "hidden hour & timezone";
  like $r, qr/reply/, "replies made of @ NOT skipped";
unlike $r, qr/real too/, "replies skipped";
unlike $r, qr/real!/, "replies skipped";
unlike $r, qr/noise/i, "noise is skipped";

$r = $f2->format_tweet($t, "toto");
like $r, qr/thetext/, "text is present, of course";
unlike $r, qr/1">#</, "hidden status link";

## twitter names linkification 
$text = '@maison, E.T telephone';
$res = $f->format_text($text);
my $maison = tweet_link('maison');
like $res, qr/$maison, E.T telephone/, "\@ are linkified";

$text = '@Capitol, yoouou';
$res = $f->format_text($text);
my $capitol = tweet_link('Capitol');
like $res, qr/^\@$capitol, yoouou$/, "\@ are linkified";

$text = '@maison, E.T telephone @maison';
$res = $f->format_text($text);
like $res, qr/$maison, E.T telephone \@maison/, "only the @ in the beginning are linkified";

$text = '@maison, @maman E.T telephone @maison';
my $maman = tweet_link('maman');
TODO: {
    local $TODO =  "more complex";
    like $text, qr/$maison, $maman E.T telephone \@maison/, "multiple links at the beginning";
}

## links
$text = 'this is http://toto.com ftp://blabla.toto';
$res = $f->format_text($text);
is $res, qq{this is <a href="http://toto.com">toto.com</a> <a href="ftp://blabla.toto">blabla.toto</a>};

## don't fuck with us. I know what I'm doing
$text = 'http://toto">com & toto';
$res = $f->format_text($text);
is $res, qq{<a href="http://toto">toto</a>&quot;&gt;com &amp; toto};

$text = 'http://toto~~.com ~1 toto';
$res = $f->format_text($text);
is $res, qq{<a href="http://toto~~.com">toto~~.com</a> ~1 toto}, "handling of legit ~";

$text = 'http://toto%7Etiti.com est toto';
$res = $f->format_text($text);
is $res, qq{<a href="http://toto%7Etiti.com">toto%7Etiti.com</a> est toto}, "ok % is not rencoded.. ";

## detenylinkification / fon.gs
sub tweet_link { $f->tweet_link(@_) }

my $f3 = Twittary::Formatter::Paragraph->new({ 
    options => { only_lifetweets => 1 },
});
$r = $f3->process([ @$alltweets ], "toto");
unlike $r, qr/thetext/, "\$t isn't a lifetweet: skipped";
  like $r, qr/real!/, "#lt is taken into account";
  like $r, qr/FAKE/, "#loudtweet etc...";
unlike $r, qr/#(lt|loud-?tweet|life-?tweet|loudtwitter)/, "#hash is removed";
unlike $r, qr/Noise/, "noise is skipped";
  like $r, qr/#noise/, "#noise shows up because #lt takes precedence";
