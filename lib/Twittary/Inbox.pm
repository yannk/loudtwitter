package Twittary::Inbox;
use strict;
use warnings;

use Email::MIME;
use Mail::Verp;

use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/ message /);

sub is_handler_for { }

sub sender { 'noreply@loudtwitter.com' }
sub verp_sender {
    my $class = shift;
    my $rcpt  = shift;
    return Mail::Verp->encode($class->sender, $rcpt);
}

sub read {
    my $self = shift;
    my $hdl = shift;
    my $text;
    {
        local $/ = undef;
        $text = <$hdl>;
    }
    return Email::MIME->new($text); 
}

1;

