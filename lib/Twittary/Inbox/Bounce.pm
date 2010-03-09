package Twittary::Inbox::Bounce;
use strict;
use warnings;

use base qw/Twittary::Inbox/;

use Mail::Verp;

use Twittary::Model::User;
use Twittary::Model::AuthToken;
use Twittary::Core;
use Twittary::Util;

sub is_handler_for { 1 }

sub process {
    my $self = shift;
    my $verp_addr = $self->message->header('To');
    Mail::Verp->separator('+');
    my ($sender, $recipient) = Mail::Verp->decode($verp_addr);

    $sender    ||= "";
    $recipient ||= "";

    Twittary::Core->log->info(
        sprintf "decoded VERP: (%s => %s)", $sender, $recipient,
    );

    ## spammer will bounce mail at us no matter what
    unless ($sender eq Twittary::Inbox->sender) {
        die "I didn't send that email: $sender";
    }

    ## It's expensive :(
    my (@users) = Twittary::Model::User->search({ endpoint_email => $recipient });
    if (@users > 1) {
        Twittary::Core->log->warn("Got a failure for a mail matching multiple users");
    }
    for my $user (@users) {
        ## we don't change next post date since it has already been
        ## done
        $user->post_failure_count(($user->post_failure_count || 0) + 1);
        $user->last_post_failure_date( Twittary::Util->now );
        $user->update;
    }
    return 1 if @users;

    my ($auth) = Twittary::Model::AuthToken->search({ token => 'email', value => $recipient });
    if ($auth) {
        Twittary::Core->log->info("User's main email is fucked :( " . $auth->user_id);
        return 1;
    }
    Twittary::Core->log->info("No action.");
    return 0;
}

1;
