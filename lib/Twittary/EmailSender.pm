package Twittary::EmailSender;
use strict;
use warnings;

use Twittary::Core;

use Email::Sender::Simple();
use Email::Sender::Transport::SMTP();
use Try::Tiny;
use UNIVERSAL::isa;

my $cfg_host = Twittary::Core->config->{SMTP}{host} ||  "localhost";
my ($host, $port) = ($cfg_host =~ /^(.+):([^:]+)$/);
$host ||= $cfg_host;

my $transport = Email::Sender::Transport::SMTP->new({
    host => $host,
    port => $port,
});

sub send {
    my $class = shift;
    my $email = shift;
    try {
        Email::Sender::Simple->send($email, { transport => $transport });
    } catch {
        my $error;
        if (UNIVERSAL::isa($_, 'Email::Sender::Failure')) {
            my $rcpts = $_->recipients;
            my $msg   = $_->message;
            my $r = join ", ", @{ $rcpts || [] };
            $error = "Failure to send to $r: $msg";
        }
        else {
            $error = "$_";
        }
        Twittary::Core->log->error("Emailer: $error");
    }
}

1;
