package Twittary::Formatter::List;
use strict;
use warnings;
use base qw/Twittary::Formatter/;

sub wrap_tweets {
    my $formatter = shift;
    my $text = shift;
    return qq{<ul class="loudtwitter">$text</ul>};
}

sub wrap_tweet {
    my $formatter = shift;
    my $text = shift;
    return "<li>$text</li>";
}

1;
