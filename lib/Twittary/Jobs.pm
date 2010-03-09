package Twittary::Jobs;
use strict;
use warnings;
use Twittary::Core;
use Twittary::Importer;
use Twittary::Model::User;
use Twittary::Model::Hit;
use Twittary::Formatter::Title;
use Gearman::Client;
use Gearman::Task;
use Storable();
use Time::HiRes();

my $cfg = Twittary::Core->config;
my $log = Twittary::Core->log;
my $job_servers = [ @{ $cfg->{GearmanServers}} ];
my $client = Gearman::Client->new( job_servers => $job_servers );

sub do_job {
    my $class   = shift;
    my $jobtype = shift;
    my $job     = shift;
    my $arg = Storable::thaw( $job->arg );

    $log->info("Working on $jobtype"); 
    my $t0 = [ Time::HiRes::gettimeofday ];

    my $success = $class->$jobtype($arg);
    my $outcome = $success ? "Succeeded" : "Failed";

    my $jobdesc = $arg->{jobdesc} || $jobtype;
    my $runtime = Time::HiRes::tv_interval($t0);
    $log->info(sprintf "%s %s in %.2f (%s)",
                $jobtype, $outcome, $runtime, $jobdesc,
              );
    return $success;
}

sub get_user {
    my $class   = shift;
    my $arg     = shift;

    my $user_id = $arg->{user_id};
    unless ($user_id) {
        $log->fatal("no user_id");
        return;
    }
    my $user = Twittary::Model::User->lookup($user_id);
    unless ($user) {
        $log->fatal("user cannot be retrieved")
    }
    my $twitter_id = $user->twitter_id || "-";
    $arg->{jobdesc} = "$user_id/$twitter_id";
    return $user;
}

sub fetch {
    my $class = shift;
    my $arg   = shift;

    my $user  = $class->get_user($arg)
        or return; 
    my $options = $arg->{options};
    my ($no_continue) = @{ $options || [] };

    my $success = eval { Twittary::Importer->missing($user, $no_continue) };
    my $twitter_id = $user->twitter_id || "-";
    if (my $err = $@) {
        $log->error(
            sprintf "Error while importing %s,%s: %s",
            $user->user_id, $twitter_id, $err
        );
	$success = 0; ## should be the case already, just make sure
    }

    return $success;
}

sub post {
    my $class = shift;
    my $arg   = shift;

    my $user = $class->get_user($arg)
        or return;

    unless ($user->can_post) {
        $log->debug("not posting because can_post=0");
        return;
    }
    ## Bail if we have posted very recently (dupe job)
    my $date = $user->last_posted_on_obj;
    if ($date && $date->clone->add(minutes => 15) > DateTime->now) {
        $log->info("We posted less than 15mn ago, not reposing again");
        return;
    }

    my $success = eval { $class->fetch({ %$arg, options => [ 'partial' ]})};
    my $err = $@;
    $log->debug("Done fetching: " . ($err || "-"));
    unless ($success) {
        $log->error("cancelling post since fetch failed");
        $user->i_failed_posting_again;
        return 0;
    }

    my $tweets = $user->daily_tweets || [];
    unless (@$tweets) {
        $log->info("Nothing to do for " .  $user->twitter_name . ", no tweets");
        $user->adjust_post_time;
        return 1;
    }
    my $scheduled = $user->next_post_date_obj;

    ## FIXME: twitter_name is not sync?
    ## XXX be sure we can post (email verified etc...)
    my $formatter = $user->formatter;
    my $content   = eval {
        $formatter->process(
            $tweets,
            $user->twitter_name,
            $user->post_prefix,
            $user->post_suffix,
            )
    };
    if ($@) {
        ## XXX fishy
        if ($@ =~ /empty list/) {
            $log->error("only replies or noise for " . $user->twitter_name);
            $user->adjust_post_time;
            return 1;
        } else {
            $log->fatal("Formatting died $@ for " . $user->twitter_name);
            return 0;
        }
    }
    my $poster = $user->poster;
    my $user_id = $user->user_id;

    eval {
        my $title = Twittary::Formatter::Title->process(
            tweets    => $tweets,
            format    => $user->post_title,
            post_date => $user->next_post_date_obj_user,
        );
        $poster->post(
            content => $content,
            title   => $title,
        );
        $user->has_posted_on($user->next_post_date_obj);
    }; if (my $err = $@) {
        $user->i_failed_posting_again;
        chomp $err;
        $log->error("fail [$err] to post " . $user->twitter_name);
        return;
    }
    my $drift = $scheduled - DateTime->now;
    my @delta = $drift->in_units('hours', 'minutes', 'seconds');
    my $secs  = 3600 * $delta[0] + 60 * $delta[1] + $delta[2];
    $log->info(sprintf "Posted %s, drift=%ds", $arg->{jobdesc}, $secs);
    return 1;
}

sub flush_stats {
    my $class = shift;
    my $arg   = shift;
    my $stats = $arg->{stats} || [];
    ## TODO: replace with straight sql and fast placeholders
    Twittary::Model::Hit->begin_work;
    eval {
        for (@$stats) {
            my ($time, $tweet_id, $user_id, $cookie, $ip, $referrer) = @$_;
            my $hit = Twittary::Model::Hit->new;
            $hit->hit_on(
                Twittary::Util->dt_to_mysql(DateTime->from_epoch(epoch => $time))
            );
            $hit->tweet_id($tweet_id);
            $hit->user_id($user_id);
            $hit->cookie($cookie);
            $hit->ip($ip);
            $hit->referrer($referrer);
            $hit->replace;
        }
    }; if (my $err = $@) {
        $log->error("Error while writing to the db: $err");
        Twittary::Model::Hit->rollback;
    }
    else {
        Twittary::Model::Hit->commit;
    }
    $log->info("Wrote " . scalar @$stats . " hits to the database" );
    return 1;
}

sub background_task {
    my $class = shift;
    my $task  = $class->create_task(@_);
    return $client->dispatch_background($task);
}

sub do_task {
    my $class = shift;
    my ($type, $user_id, $timeout) = @_;
    my $task = $class->create_task($type, $user_id);
    $task->timeout($timeout) if $timeout;
    return $client->do_task($task);
}

sub create_task {
    my $class   = shift;
    my $type    = shift;
    my $user_id = shift;
    my @rest    = @_;
    my $task = Gearman::Task->new(
        $type,
        \Storable::nfreeze({
            user_id => $user_id,   
            options => \@rest,
        }),
        {
            ## XXX i don't trust uniq implementation. Test
            #uniq => '-',
            uniq => "$type-$user_id",
        },
    );
    return $task;
}

1;

