package Twittary::Model::User;
use strict;
use warnings;

use base qw( Data::ObjectDriver::BaseObject );
use DateTime;
use Twittary::API::User;
use Twittary::Model::AuthToken;
use Twittary::Model::Tweet;
use Twittary::TweetDriver;
use Twittary::Util;
use Twittary::Core;

# XXX i need an abstract base class!
use Twittary::Poster::Email;
use Twittary::Poster::Atom;
use Twittary::Poster::TypePad;
use Twittary::Poster::XMLRPC;

use Math::BaseCalc;
my $calc36 = new Math::BaseCalc( digits => [ 0 .. 9, 'a' .. 'z' ] );

__PACKAGE__->install_properties({
    columns => [
        qw/user_id name twitter_id twitter_name
           last_fetched_on next_post_date
           timezone post_hour post_minute
           endpoint_email endpoint_atom endpoint_user endpoint_pass
           endpoint_xmlrpc last_posted_on 
           post_failure_count last_post_failure_date
           post_prefix post_suffix post_title post_using_guest
           password email_verified email_challenge has_suspended
           preferred_posting_method formatter_type no_fetch
           format_hide_status_link format_hide_replies format_hide_time
           format_only_lifetweets created_on locale
           / 
    ],
    column_defs => {
        last_fetched_on        => 'date',
        last_posted_on         => 'date',
        next_post_date         => 'date',
        created_on             => 'date',
        last_post_failure_date => 'date',
    },
    datasource  => 'user',
    primary_key => 'user_id',
    driver      => Twittary::TweetDriver->driver,
});

sub shid {
    my $user = shift;
    my $id = $user->user_id;
    use Math::BigInt;
    return $calc36->to_base(Math::BigInt->new($id));
}

# the name to display in the upper login box
sub login_name {
    my $user = shift;
    return $user->name || $user->openid_uri || $user->email;
}

sub lookup_by_shid {
    my $class = shift;
    my($shid) = @_;
    my $str = from_base36($shid);
    return $class->lookup($str);
}

# Stuck on 32bits machine... need some hackery
sub from_base36 {
    my $str = shift;
    my $dignum = 36;

    $str = reverse $str;
    my $result = Math::BigInt->new("0");
    while (length $str) {
        # For large numbers, force result to be an integer (not a float)
        $result = $result*$dignum + $calc36->{trans}{chop $str};
    }
    return $result;
}

sub email {
    my $user = shift;
    my $tok = $user->auth_tokens;
    my($email) = grep { $_->token eq 'email' } @$tok;
    return unless $email;
    return $email->value;
}

sub openid_uri {
    my $user = shift;
    my $tok = $user->auth_tokens;
    my($url) = grep { $_->token eq 'openid_uri' } @$tok;
    return unless $url;
    return $url->value;
}

sub auth_tokens {
    my $user = shift;
    unless (exists $user->{__auth_tokens}) {
        my @tokens = Twittary::Model::AuthToken->search({
            user_id => $user->user_id,
        });
        $user->{__auth_tokens} = \@tokens;
    }
    return $user->{__auth_tokens};
}

sub add_token {
    my $user = shift;
    my($tok, $val) = @_;
    my $token = Twittary::Model::AuthToken->new;
    $token->user_id($user->user_id);
    $token->token($tok);
    $token->value($val);
    $token->insert;
}

sub lookup_by_openid {
    my $class = shift;
    return Twittary::Model::AuthToken->lookup_by(token => 'openid_uri', value => shift);
}

sub lookup_by_email {
    my $class = shift;
    return Twittary::Model::AuthToken->lookup_by(token => 'email', value => shift);
}

sub is_fully_registered {
    my $user = shift;
    return 1 if (
           ( $user->twitter_name || $user->twitter_id )
        && $user->has_endpoint
        && $user->next_post_date
#        && $user->has_full_creds
    ); 
}

sub has_endpoint {
    my $user = shift;
    return 1 if (
           $user->endpoint_email
        || $user->endpoint_atom
        || $user->endpoint_xmlrpc
    )
}
sub can_post {
    my $user = shift;
    return 0 if $user->has_suspended;
    return 0 unless $user->is_fully_registered;
    unless ($user->openid_uri) {
        return 0 unless $user->email && $user->email_verified;
    }
    return 1;
}

sub post_time {
    my $user = shift;
    return join ':', map { $_ || "" } ($user->post_hour, $user->post_minute);
}

sub last_20 {
    my $user = shift;
    return Twittary::Model::Tweet->last_20_of($user->user_id);
}

sub last_tweet {
    my $user = shift;
    my ($last) = Twittary::Model::Tweet->search(
        { user_id => $user->user_id },
        { limit => 1, sort => 'created_at', direction => 'descend' },
    );
    return $last;
}

sub last_fetched_on_http_date {
    my $user = shift;
    my $date = $user->last_fetched_on || return;
    return Twittary::Util->mysql_to_http($date);
}

sub daily_tweets {
    my $user = shift;
#    my $last = $user->last_posted_on_obj || 
## XXX may want to repost thing that we missed ?
##  take the max / min of last_posted_on and yesterday
    my $last = DateTime->now->subtract(days => 1);
    $last = Twittary::Util->dt_to_mysql($last);
    my @tweets = Twittary::Model::Tweet->search(
        { user_id => $user->user_id,
          created_at => { op => '>=', value => $last },
        },
    );
    return \@tweets;
}

sub poster {
    my $user = shift;
    # uglyness which just works, I don't care
    my $preferred = $user->preferred_posting_method;
    if ($preferred) {
        if ($preferred eq 'guest' && $user->post_using_guest) {
            return Twittary::Poster::TypePad->new(
                endpoint => $user->endpoint_atom,
            );
        }
        if ($preferred eq 'atom' && $user->endpoint_atom) {
            return Twittary::Poster::Atom->new(
                endpoint => $user->endpoint_atom,
                username => $user->endpoint_user,
                password => $user->endpoint_pass,
            );
        }
        if ($preferred eq 'xmlrpc' && $user->endpoint_xmlrpc) {
            return Twittary::Poster::XMLRPC->new(
                endpoint => $user->endpoint_xmlrpc,
                username => $user->endpoint_user,
                password => $user->endpoint_pass,
            );
        }
        if ($preferred eq 'email' && $user->endpoint_email) {
            return Twittary::Poster::Email->new(
                email => $user->endpoint_email,
            );
        }
    }
    if ($user->post_using_guest) {
        return Twittary::Poster::TypePad->new(
            endpoint => $user->endpoint_atom,
        );
    }
    if ($user->endpoint_email) {
        return Twittary::Poster::Email->new(
            email => $user->endpoint_email,
        );
    }
    if ($user->endpoint_xmlrpc) {
        return Twittary::Poster::XMLRPC->new(
            endpoint => $user->endpoint_xmlrpc,
            username => $user->endpoint_user,
            password => $user->endpoint_pass,
        );
    }
    return Twittary::Poster::Atom->new(
        endpoint => $user->endpoint_atom,
        username => $user->endpoint_user,
        password => $user->endpoint_pass,
    );
}

sub formatting_options {
    my $user = shift;
    my $cols = $user->column_values;
    my %opts = map { my $key = $_; $key =~ s/^format_//g; ($key => $cols->{$_}) } grep { /^format_/ } keys %$cols;
    return \%opts;
}

sub formatter {
    my $user = shift;
    # XXX I really need to find an AbstractFactory on CPAN or upload one
    use Twittary::Formatter::List;
    use Twittary::Formatter::Paragraph;
    my $class = 'Twittary::Formatter::List';
    if ($user->formatter_type && $user->formatter_type eq 'para') {
        $class = 'Twittary::Formatter::Paragraph';
    }
    return $class->new({ options => $user->formatting_options });
}

sub shipment_method {
    my $user = shift;
    my $poster = $user->poster || return;
    return $poster->id;
}

sub import_tweet {
    my $user = shift;
    my $data = shift;
    return Twittary::Model::Tweet->import_tweet($user->user_id, $data);
}

sub typepad_guest_email {
    my $user = shift;
    return Twittary::API::User->typepad_guest_email($user);
}


# take posted date in parameter (UTC)
# add +1d
# convert to user tz
# set user hour and time
# convert back to UTC --> next_post_date
sub has_posted_on {
    my $user = shift;
    my($date) = @_;
    
    my $user_id  = $user->user_id;
    my $previous = $user->next_post_date;
    my $prev_lp  = $user->last_posted_on;

    $date->set_time_zone('UTC'); # be sure it's utc
    my $last_post = $date->clone;
    my $now = DateTime->now;
    do { $date->add(days => 1) } until $date > $now;
    $date->set_time_zone($user->timezone || 'UTC');
    my $clone = $date->clone; # cloning just because I don't know side effects
    eval{  $clone->set( hour => $user->post_hour, minute => $user->post_minute); };
    if (my $err = $@) {
        $clone = $date->clone;
        Twittary::Core->log->error("Hit an exception. DST? $user_id $date: $err");
        eval{  $clone->set( hour => $user->post_hour + 1, minute => $user->post_minute); };
    }
    $date = $clone;
    $date->set_time_zone('UTC');
    $user->next_post_date(Twittary::Util->dt_to_mysql($date));
    $user->last_posted_on(Twittary::Util->dt_to_mysql($last_post));
    $user->reset_post_failure;
    Twittary::Core->log->info(sprintf
        "DATE uid:%s, next:%s nlp:%s previous:%s, prev_lp:%s, tz:%s@%d:%d",
        $user_id,
        $user->next_post_date,
        $user->last_posted_on,
        $previous || "-",
        $prev_lp || "-",
        $user->timezone || "-",
        $user->post_hour,
        $user->post_minute,
    );
    $user->update;
}

# do the same than the above but with now's date.
# we are sure that the next tweets will be posted in < 24h
sub adjust_post_time {
    my $user = shift;
    my $date = DateTime->now;
    $date->set_time_zone($user->timezone || 'UTC');
    $date->set( hour => ($user->post_hour || 00), minute => ($user->post_minute || 0));
    $date->set_time_zone('UTC');
    my $now = DateTime->now;
    $now->add(minutes => 15); ## give some slack to the process...
    if ($date < $now) {
        do { $date->add(days => 1) } until $date > $now;
    }
    $user->next_post_date(Twittary::Util->dt_to_mysql($date));
    Twittary::Core->log->info(
        sprintf "Adjusting post_time for uid:%s, next:%s",
                $user->user_id,
                $user->next_post_date,
    );
    $user->update;
}

sub next_post_date_obj {
    my $user = shift;
    return unless $user->next_post_date;
    my $dt = Twittary::Util->mysql_to_dt($user->next_post_date);
    return $dt;
}

sub next_post_date_obj_user {
    my $user = shift;
    return unless $user->next_post_date;
    my $dt = Twittary::Util->mysql_to_dt($user->next_post_date);
    $dt->set_time_zone($user->timezone || "UTC");
    return $dt;
}

sub next_post_date_local {
    my $user = shift;
    my $date = $user->next_post_date_obj;
    $date->set_time_zone('America/Los_Angeles');
    return $date->iso8601;
}

## DRY XXX
sub last_posted_on_obj {
    my $user = shift;
    return unless $user->last_posted_on;
    my $dt = Twittary::Util->mysql_to_dt($user->last_posted_on);
    return $dt;
}

## DRY XXX
sub last_fetched_on_obj {
    my $user = shift;
    return unless $user->last_fetched_on;
    my $dt = Twittary::Util->mysql_to_dt($user->last_fetched_on);
    return $dt;
}

use DateTime::Format::DateManip;
use Date::Manip();
sub eta_before_next {
    my $user = shift;
    my $next = $user->next_post_date_obj;
    return "" unless $next;
    my $dur = $next - DateTime->now;
    my $delta = DateTime::Format::DateManip->format_duration($dur);
    if ($delta =~ m/^-/) {
        return "anytime soon... contact us if something looks wrong";
    }
    my($h, $m) = Date::Manip::Delta_Format($delta, undef, 'in %hv hour(s) %mv minute(s)');
    return $h if $h;
}

sub i_failed_posting_again {
    my $user  = shift;
    my $count = $user->post_failure_count || 0;
    my $secs  = 2 ** $count + rand(120); ## exponential backoff
    my $next  = DateTime->now->add( seconds => $secs );
    $user->post_failure_count($count + 1);
    $user->last_post_failure_date( Twittary::Util->now );
    $user->next_post_date( Twittary::Util->dt_to_mysql($next) );
    $user->update;
}

## XXX there is a big problem where sending email is always
## successful so we'll reset this counter and the mail will bounce
## anyway, but we'll know too late...
sub reset_post_failure {
    my $user = shift;
    return unless $user->post_failure_count;
    $user->post_failure_count(0);
    $user->last_post_failure_date(undef);
    $user->update;
}

sub reset_for_next_post {
    my $user = shift;
    $user->reset_post_failure;
    $user->adjust_post_time;
    return 1;
}

sub last_post_failure_date_user {
    my $user = shift;
    my $lpfd = $user->last_post_failure_date;
    return '' unless $lpfd;
    my $datestr = eval {
        my $last = Twittary::Util->mysql_to_dt($lpfd);
        $last->set_time_zone($user->timezone || 'UTC');
        $last->iso8601;
    };
    return $datestr;
}

1;
