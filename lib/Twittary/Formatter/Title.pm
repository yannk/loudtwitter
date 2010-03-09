package Twittary::Formatter::Title;
use strict;
use warnings;

use Carp;

sub format {
    my $class = shift;
    my ($cfg, $format) = @_;
    my $date = $cfg->{post_date}
        or croak "'post_date' MUST be specified in the configuration hash"; 
    my $out = $date->format_cldr($format);
    $out =~ s/%NR/$cfg->{number_of_replies}/g;
    $out =~ s/%NT/$cfg->{number_of_tweets}/g;
    return $out;
}

sub process {
    my $class = shift;
    my %param = @_;

    my $format    = $param{format} || "";
    return $format unless $format =~ /^fmt=(.*)$/;
    $format = $1;

    my $tweets    = $param{tweets} || [];
    my $n_tweets  = scalar @$tweets;
    my $n_replies = scalar grep { $_->is_reply } @$tweets;

    my $date = $param{post_date} or croak "you MUST specify 'post_date'";

    ## Deal with early morning tweets
    ## We consider these to be previous day tweets
    if ($date->hour < 9) {
        $date->add( days => -1 );
    }
    my $cfg = {
        post_date         => $date,
        number_of_replies => $n_replies,
        number_of_tweets  => $n_tweets,
    };
    return $class->format($cfg, $format);
}

1;
