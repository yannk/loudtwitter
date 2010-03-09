package Twittary::API::User;
use strict;
use warnings;

use Email::Simple;
use Email::Simple::Creator;
use Twittary::EmailSender;
use Twittary::Inbox;
use Twittary::Model::AuthToken;
use Twittary::Model::Tweet;
use Twittary::Model::User;
use Twittary::Util;
use Twittary::Jobs;
use Twittary::Formatter::Title;

sub delete {
    my $class = shift;
    my(%params) = @_;
    my $user = $params{user}
        or die "need a user";
    ## and yes I will think about changing these lines when memcached
    ## will be all around
    Twittary::Model::AuthToken->remove({ user_id => $user->user_id });
    Twittary::Model::Tweet    ->remove({ user_id => $user->user_id });
    return $user->remove;
}

## XXX need tests
sub find {
    my $class = shift;
    my $id = shift;

    my $user;
    if ($id =~ /^\d+$/) {
        $user = Twittary::Model::User->lookup($id);
    } 
    elsif ($id =~ /\@/) {
        $user = Twittary::Model::User->lookup_by_email($id);
    }
    elsif ($id =~ m{^(http://)?.+\..+\.}) {
        $user = Twittary::Model::User->lookup_by_openid($id);
    } else {
        die "Don't know how to find $id";
    }
    
    return $user;
}

sub reset_password {
    my $class = shift;
    my $user = shift;

    my $code = generate_code();

    ## reuse this field. This is a hack
    $user->email_challenge($code);
    $user->update;

    my $site = Twittary::Core->config->{baseuri} ||  "www.loudtwitter.com";
    my $to = $user->email
        or die "no email !";

    my $shid = $user->shid;

    my $email = Email::Simple->create(
       header => [
            From    => Twittary::Inbox->sender,
            To      =>  $to,
            Bcc     =>  'loudtwitter@gmail.com',
            Subject => 'LoudTwitter: password reset',
          ],
          body => <<EOM,

You asked to reset your LoudTwitter password associated with this email.
Please ignore this message if you didn't request that change, your password
will stay the same.

To reset your password, click on the following link:

http://$site/reset-password/$shid/$code

and follow the instructions.

Rergards,

LT
EOM
    );

    Twittary::EmailSender->send($email);
}

sub fucked_invite {
    my $class = shift;

    my $email = Email::Simple->create(
       header => [
            From    => Twittary::Inbox->sender,
            To      =>  'loudtwitter@gmail.com',
            Subject => 'LoudTwitter: fucked invite!',
          ],
          body => <<EOM,
Salut Yann.
Fucked typepad invite.
EOM
    );

    Twittary::EmailSender->send($email);
}

sub untrust_email {
    my $class = shift;
    my $user = shift;
    my $code = generate_code();
    $user->email_challenge($code);
    $user->email_verified(0);
    $user->update;

    my $blob = join "-", $code, $user->shid;
    my $site = Twittary::Core->config->{baseuri} ||  "www.loudtwitter.com";
    my $to = $user->email
        or die "no email !";
    my $email = Email::Simple->create(
       header => [
            From    => Twittary::Inbox->sender,
            To      =>  $to,
            Bcc     =>  'loudtwitter@gmail.com',
            Subject => 'LoudTwitter verification of your email',
          ],
          body => <<EOM,

Hello,

Straight to the point! your activation code is: $blob

click on this link to verify your account. Thanks!
http://$site/email-verify/$blob

EOM
    );

    Twittary::EmailSender->send($email);
}

sub email_already_verified {
    my $class  = shift;
    my $addr  = shift or die "no email !";

    my $site = Twittary::Core->config->{baseuri} ||  "www.loudtwitter.com";
    my $email = Email::Simple->create(
       header => [
            From    => Twittary::Inbox->sender,
            To      =>  $addr,
            Bcc     =>  'loudtwitter@gmail.com',
            Subject => 'LoudTwitter email verified',
          ],
          body => <<EOM,

Hi, someone (probably you) asked about details related to this email.
If not, sorry for the inconvenience and  please disregard this email.

Your email is already verified and associated to your LoudTwitter account
there is nothing else for you to do.

Regards,

LT

EOM
    );

    Twittary::EmailSender->send($email);
}

sub email_not_found {
    my $class  = shift;
    my $addr  = shift or die "no email !";
    my $reason = shift; 

    my $what = $reason eq 'password' 
             ? "Forgotten password email"
             : "Account confirmation email";
    my $site = Twittary::Core->config->{baseuri} ||  "www.loudtwitter.com";
    my $instructions = "http://$site/password";
    my $email = Email::Simple->create(
       header => [
            From    => Twittary::Inbox->sender,
            To      =>  $addr,
            Bcc     =>  'loudtwitter@gmail.com',
            Subject => 'LoudTwitter email not found',
          ],
          body => <<EOM,

$what

Hi, someone (probably you) asked about details related to this email.
Unfortunately LoudTwitter was unable to find your email within its database.

Please make sure that you didn't create your account using OpenID:
read instructions here: $instructions
If you haven't requested this email, we're sorry for the inconvenience, please
ignore this message.

Regards,

LT

EOM
    );

    Twittary::EmailSender->send($email);
}

sub generate_code {
    my $code = '';
    my $digits = 'abcdefghijklmnopqrstuvwzyzABCDEFGHIJKLMNOPQRSTUVWZYZ0123456789';
    my $total = length $digits;
    for (1 .. 6) {
        $code .= substr($digits, int(rand $total), 1);
    }
    return $code;
}


sub verify_email {
    my($class, %params) = @_;
    my $user = $params{user};
    my $code = $params{code};

    my $challenge = $user->email_challenge || "";
    my $already_verified = $user->email_verified;
    if ($already_verified) {
        die "Email has been verified already";
    }
    if ($challenge eq $code) {
        $user->email_verified(1);
        $user->email_challenge(undef);
        $user->adjust_post_time;
        $user->update;
        return 1;
    } else {
        die "The code doesn't match $code";
    }
    return;
}

sub add_twittary_guest {
    my($class, %params) = @_;
    my $user = $params{user};
    my $atom_uri = $params{uri};
    $user->endpoint_atom($atom_uri);
    $user->post_using_guest(1);
    return $user->save;
}

sub typepad_guest_email {
    my $class = shift;
    my $user = shift;
    my $shid = $user->shid;
    return sprintf "loudly+%s\@loudtwitter.com", $shid;
}

sub test_setup {
    my $class   = shift;
    my %param   = @_;
    my $user    = $param{user};
    my $poster  = $user->poster;

    ## now try to get some legit to post
    my $content = $class->try_to_get_test_content($user);
    eval {
        my $title = Twittary::Formatter::Title->process(
            tweets    => $class->fake_tweets,
            format    => $user->post_title,
            post_date => $user->next_post_date_obj_user,
        );
        $poster->post(content => $content, title => $title);
    };
    my $err = $@;
    unless ($err) {
        $user->reset_for_next_post;
    }
    return $err;
}

sub try_to_get_test_content {
    my $class     = shift;
    my $user      = shift;
    my $formatter = $user->formatter;

    my $daily_tweets = $user->daily_tweets;
    unless ($daily_tweets and @$daily_tweets) {
        ## synchronously fetch tweets, and wait 1.8s
        eval { Twittary::Jobs->do_task('fetch', $user->user_id, 1.8) };
    }
    my @methods = (
        sub { $user->daily_tweets },
        sub { $user->last_20      },
        sub { $class->fake_tweets },
    );
    my $tweets;
    for my $method (@methods) {
        $tweets = $method->() || [];
        last if @$tweets;
    }
    my $prefix  = "This is the TEST (some parts are faked) shipment "
                . "you asked for <br /><br />"
                . $user->post_prefix;

    my $content = $formatter->process(
        $tweets,
        $user->twitter_name,
        $prefix,
        $user->post_suffix,
    );
    return $content;
}

sub fake_tweets {
    my $class = shift;
    my $tweets = [];
    for (1 .. 2) {
        my $t = Twittary::Model::Tweet->new;
        $t->tweet_id(1234567890);
        $t->created_at(Twittary::Util->dt_to_mysql(DateTime->now));
        $t->user_id( 1 );
        $t->text("I couldn't find a tweet to post for loudtwitter");
        $t->text("So I posted this.") if $_ == 2;
        push @$tweets, $t;
    }
    return $tweets;
}

1;
