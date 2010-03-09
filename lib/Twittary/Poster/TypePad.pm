package Twittary::Poster::TypePad;
use strict;
use warnings;

use base qw/Twittary::Poster::Atom/;
use Twittary::TypePad;

sub id { 'guest' }

sub init {
    my $poster = shift;
    $poster->SUPER::init(@_);
    $poster->{username} = Twittary::TypePad->GUEST_USER; 
    $poster->{password} = Twittary::TypePad->GUEST_PASS; 
}

1;
