package Twittary::Fetcher;
use strict;
use warnings;

use LWP::UserAgent;
use JSON::Any;
use YAML;
use URI;
use URI::Escape;
use Twittary::Core; # tmp
use URI::QueryParam;
use HTTP::Request;
use HTTP::Headers;

## TODO:
## Use timeout, don't hang on one http socket for ever
## log callbacks (instead of warn)?
my $log = Twittary::Core->log;

sub get_since {
    my $fetcher = shift;
    my %param   = @_;
    return $fetcher->get_since_date(@_) if $param{since};
    return $fetcher->get_since_id(@_);
}

sub get_since_date {
    my $fetcher = shift;
    my(%param) = @_;
    my $since = $param{since};
    my $twitter_id = $param{twitter_id}
        or die "twitter_id is missing";
    my $ua = LWP::UserAgent->new;
    $ua->env_proxy;
    use HTTP::Request;
    use HTTP::Headers;
    my $h = HTTP::Headers->new;
    $h->user_agent("Hang on this is LoudTwitter");
    $h->authorization_basic( "loudtweeter", "itsnottherealpassworddonttry" );
    if ($since) {
        #$since = 'Sat, 30 Jun 2007 20:00:00 GMT';
        $h->header('If-Modified-Since', $since);
    }
    my $count = $param{count} || 200;
    my $url = "http://twitter.com/statuses/user_timeline.json"
            . "?user_id=$twitter_id?count=$count";
    my $request = HTTP::Request->new( GET => $url, $h );
    my $response = $ua->request($request);
    if (!$response->is_success) {
        return if $response->code eq '304';
        die "Ooos failed! $twitter_id " . $response->status_line;
    }
    if ($response->content_type !~ /json/) {
        die "Ooos failed! $twitter_id : content-type is " . $response->content_type;
    }
    my $json = JSON::Any->jsonToObj($response->content);
    die "no result from json ".  $response->content unless $json;
    return $json;
}

sub get_ua {
    my $fetcher = shift;
    my $ua = LWP::UserAgent->new;
    $ua->env_proxy;
    return $ua;
}

sub user_timeline_uri {
    my $fetcher = shift;
    my %param   = @_;

    my $user_id = $param{twitter_id};
    my $uri = URI->new("http://twitter.com/statuses/user_timeline.json");
    $uri->query_form_hash({
        user_id => $user_id,
        count   => $param{count},
        page    => $param{page},
    });
    $uri->query_param_append(
        since_id => $param{since_id}
    ) if $param{since_id};
    return $uri;
}

sub user_timeline_req {
    my $fetcher = shift;
    my $uri = $fetcher->user_timeline_uri(@_);
    my $h = HTTP::Headers->new;
    $h->user_agent("Hang on tight, this is LoudTwitter");
    $h->authorization_basic( "loudtweeter", "itsnottherealpassworddonttry" );
    my $request = HTTP::Request->new( GET => $uri, $h );
}

sub get_request {
    my $fetcher = shift;
    my $uri     = shift;
    my $h = HTTP::Headers->new;
    $h->user_agent("Hang on tight, this is LoudTwitter");
    $h->authorization_basic( "loudtweeter", "itsnottherealpassworddonttry" );
    return HTTP::Request->new( GET => $uri, $h );
}

sub get_since_id {
    my $fetcher = shift;
    my(%param) = @_;

    die "no twitter_id" unless $param{twitter_id};

    my $ua        = $fetcher->get_ua();

    my $count     = $param{count}    || 200;
    my $since_id  = $param{since_id} || "";
    my $max_page  = $param{max_page};
    my $safeguard = 0;
    my $page      = 1;
    my $all       = [];
    my $json      = [];

    my $uri = $fetcher->user_timeline_uri(
        twitter_id => $param{twitter_id},
        count      => $count,
        since_id   => $since_id,
    );
    eval {
        do {
            ## set the page number
            $uri->query_param(page => $page);
            $log->info($uri);
            my $request  = $fetcher->get_request($uri);
            my $response = $ua->request($request);
            if (!$response->is_success) {
                die "Ooos failed! $param{twitter_id} "
                    . $response->status_line;
            }
            if ($response->content_type !~ /json/) {
		$log->debug("no json: " . $response->content);
                die "Ooos failed! $param{twitter_id} : content-type is "
                    . $response->content_type;
            }
            $json = JSON::Any->jsonToObj($response->content);
            die "no result from json ".  $response->content unless $json;
            push @$all, @$json;
            $page++;
        }
        until (
              !$param{continue}                  ## stop after first iteration
            or scalar @$json < $count            ## if a page is not complete
            or ($max_page && $page > $max_page)  ## if we specified a max page
            or $safeguard++ > 1000               ## ...just in case
        );
    };
    if (my $err = $@) {
        warn ("Oops $err");
        die $@ unless @$all;
    }
    return $all;
}

## Returns -1 if twitter name is protected
## Returns  0 if twitter name is not found or other error
## Otherwise returns the twitter_id
sub verify_twitter_name {
    my $fetcher = shift;
    my $twitter_name = shift;
    my $ua = LWP::UserAgent->new;
    $ua->env_proxy;
    $ua->agent("LoudTwitter");
    $twitter_name = URI::Escape::uri_escape_utf8($twitter_name);
    my $url = sprintf
              "http://twitter.com/users/show.json?screen_name=%s",
              $twitter_name;
    my $response = $ua->get($url);
    Twittary::Core->log->debug($response->content);
    my $json = JSON::Any->jsonToObj($response->content);
    return 0 if $response->code =~ m/^40/;
    return 0 unless $json;
    return -1 if $json->{protected};
    return $json->{id};
}

1;
