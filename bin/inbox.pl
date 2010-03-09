#! /usr/bin/perl
use strict;
use warnings;

use constant DELIVERED => 0;
use constant REJECTED  => 100;

use Find::Lib '../lib' => 'Twittary::Bootstrap';

use Twittary::Core;
use Twittary::Inbox;
use Twittary::Inbox::TypePadInvites;
use Twittary::Inbox::Bounce;
Twittary::Core->log->info("incoming mail");

eval {
    my $inbox;
    my $message = Twittary::Inbox->read(\*STDIN);
    for my $hdlr (qw/ TypePadInvites Bounce /) {
        my $class = "Twittary::Inbox::$hdlr";
        if ($class->is_handler_for($message)) {
            $inbox = $class->new({ message => $message });
            last;
        }
    }
    unless ($inbox) {
        my $to   = $message->header('To')      || "";
        my $from = $message->header('From')    || "";
        my $subj = $message->header('Subject') || "";
        die "No handler for $to $from $subj";
    }
    $inbox->process;
};
if ($@) {
    Twittary::Core->log->info("error processing: $@");
    exit REJECTED;
} else {
    exit DELIVERED;
}
