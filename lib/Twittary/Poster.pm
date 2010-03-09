package Twittary::Poster;
use strict;
use warnings;

sub new {
    my $class = shift;
    my(%config) = @_;
    %config = () unless %config;
    my $self = bless \%config, ref $class || $class;
    $self->init(@_);
    return $self;
}

sub init;

sub default_title   { "Tweets for Today"      }
sub default_content { "Oops an error occured" }

sub id { ref shift }

sub post {
    my $poster = shift;
    return $poster->transport(@_);
}

1;
