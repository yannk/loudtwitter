package Twittary::Formatter;
use strict;
use warnings;
use URI::Escape;
use Carp();

use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors('options');

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->options({}) unless $self->options;
    return $self;
}

sub process {
    my $formatter = shift;
    my $tweets    = shift;
    my $user      = shift || 'loiclemeur';
    my $prefix    = shift || '';
    my $suffix    = shift || '';
    my $track     = shift || '';
    my @tweets    = $formatter->filter($tweets);
    Carp::croak("empty list of tweets after filtering") unless @tweets;
    my @formatted =  map { $formatter->format_tweet($_, $user) } @tweets;
    my $text = join " ", map { $formatter->wrap_tweet($_) } @formatted;
    return $prefix . "\n\n" . $formatter->wrap_tweets($text) . $suffix . $track; 
}

sub wrap_tweets { Carp::croak("subclass") }
sub wrap_tweet  { Carp::croak("subclass") }

sub filter {
    my $formatter = shift;
    my $tweets    = shift;

    ## filter noise, unless we are inclusive
    unless ($formatter->options->{only_lifetweets}) {
        @$tweets = grep { ! $_->is_noise } @$tweets;
    }
    if ($formatter->options->{hide_replies}) {
        @$tweets = grep { ! $_->is_reply } @$tweets;
    }
    if ($formatter->options->{only_lifetweets}) {
        @$tweets = grep { $_->is_lifetweet } @$tweets;
    }
    return @$tweets;
}

sub format_tweet {
    my $formatter = shift;
    my $tweet = shift;
    my $user = shift;

    my $id = $tweet->tweet_id;
    my $time = '';
    unless ($formatter->options->{hide_time}) {
        $time = join '', "<em>", $tweet->created_at_obj->strftime('%H:%M'), "</em> ";
    }
    my $pound = '';
    unless ($formatter->options->{hide_status_link}) {
        $pound = qq{ <a href="http://twitter.com/$user/statuses/$id">#</a>};
    }
    my $tweet_text = $tweet->text;
    if ($formatter->options->{only_lifetweets}) {
        my $re = $tweet->lt_regex;
        $tweet_text =~ s/$re//smg;
    }
    my $text = $formatter->format_text($tweet_text);
    return $time . $text . $pound;
}

sub format_text {
    my $formatter = shift;
    my $text = shift;
    my @subs = ();
    $text =~ s/~/~~/g;
    $formatter->format_links(\@subs, \$text);
    $formatter->format_replies(\@subs, \$text)
        unless $formatter->options->{hide_replies};
    $text = $formatter->html($text);
    my $i = 1;
    for (@subs) {
        $text =~ s/(^|[^~])~$i/$1$_/g;
        $i++;
    }
    $text =~ s/~~/~/g;
    return $text;
}

sub format_replies {
    my $formatter = shift;
    my $subs = shift;
    my $textref = shift;
    $$textref =~ s!^(\W*)\@(\w+)
                  !_name_pattern($formatter, $subs, $1, $2)
                  !xe;
}

sub _name_pattern {
    my($formatter, $subs, $junk, $tweet_name) = @_;
    push @$subs, join '@', $junk, $formatter->tweet_link($tweet_name);
    my $anchor = '~' . scalar @$subs;
    return $anchor;
}

sub format_links {
    my $formatter = shift;
    my $subs = shift;
    my $textref = shift;
    $$textref =~ s!(https?|ftp|mailto)://([\w.%\$\#@\!\?*&~/;:,-=\+^]+)
                  !_link_pattern($formatter, $subs, $1, $2)
                  !xeg;
}

sub _link_pattern {
    my($formatter, $subs, $schema, $link) = @_;
    my $uri_link = $link;
    $link = $formatter->html($link);
    push @$subs, qq{<a href="$schema://$uri_link">$link</a>};
    my $anchor = '~' . scalar @$subs;
    return $anchor;
}

sub tweet_link {
    my $formatter = shift;
    my $tn = shift;
    my $tnl = $formatter->uri(lc $tn);
    $tn = $formatter->html($tn);
    return qq{<a href="http://twitter.com/$tnl">$tn</a>};
}

sub html {
    my $class = shift;
    my $text = shift;
    for ($text) {
        s/&/&amp;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        s/"/&quot;/g;
    }
    return $text;
}

sub uri {
    my $class = shift;
    return URI::Escape::uri_escape_utf8(shift)
}

1;
