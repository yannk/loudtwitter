package Twittary::Formatter::Paragraph;
use strict;
use warnings;
use base qw/Twittary::Formatter/;

sub wrap_tweets {
    my $formatter = shift;
    my $text = shift;
    return $text;
}

sub wrap_tweet {
    my $formatter = shift;
    my $text = shift;
    return qq{<p class="loudtwitter">$text</p>};
}

1;
