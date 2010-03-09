package Twittary::Poster::Email;
use strict;
use warnings;

use base qw/Twittary::Poster/;

use Twittary::Inbox;
use Twittary::EmailSender;
use Email::MIME;
use Email::MIME::Creator;
use Email::Simple;
use Email::Simple::Creator;

sub id { 'email' }

sub init {
    my $self = shift;
}

sub transport {
    my $poster = shift;
    my(%param) = @_;

    my $to       = $poster->{email} || die "I need a recipient";
    my $track    = $param{track}    || "";
    my $content  = $param{content}  || $poster->default_content;

    ## exclude obvious destinations for which tracking is useless
    ## or worse harmful
    $content .= $track unless $to =~ /gmail|yahoo/; 

    my $email = Email::MIME->create(
        header => [
            From    => Twittary::Inbox->sender,
            To      => $to,
            Subject => $param{title} || "",
        ],
        attributes => {
            content_type => "text/html",
            charset      => "utf-8",
        },
        body => $content,
    );
    my $result = Twittary::EmailSender->send($email);
    unless ($result) {
        die "Error sending email: $result";
    }
    return 1;
}

1;
