package Twittary::Controller::Donate;
use strict;
use warnings;

use base 'Catalyst::Controller';

sub default : Private {
    my($self, $c) = @_;
    $c->stash->{template} = 'donate/paypal.tt';
}

sub thanks : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'donate/thanks.tt';
}

1;
