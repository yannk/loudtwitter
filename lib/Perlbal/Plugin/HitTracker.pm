package Perlbal::Plugin::HitTracker;
use strict;
use warnings;

use HTTP::Date();
use Crypt::Random();
use Gearman::Client::Async;
use Gearman::Task;
use Perlbal::Util;
use Perlbal;
use bytes;

## servers should really come from the configuration
my $gearman  = Gearman::Client::Async->new(job_servers => [ '127.0.0.1:7003', '127.0.0.1:4730' ]);
my $Pause    = 0;
my @Stats    = ();
my %Services = ();

use constant GIFBIN => "GIF89a\x01\0\x01\0\x80\0\0\0\0\0\xff\xff\xff\x21\xf9\x04\x01\0\0\0\0\x2c\0\0\0\0\x01\0\x01\0\x40\x02\x02\x44\x01\0\x3b";
use constant DEFAULT_MAX_SIZE => 100;

sub load {
    Perlbal::register_global_hook('manage_command.hits', sub {
        my @res = ("Hit Tracker:");
        push @res, $Pause ? "PAUSED" : "RUNNING";
        push @res, "curent size = " . scalar @Stats;
        foreach my $svc (values %Services) {
            my $current_size = $svc->{extra_config}->{hit_tracker_max_size} || DEFAULT_MAX_SIZE;
            push @res, "SET $svc->{name}.hittracker.max_size = $current_size";
        }
        push @res, ".";
        return \@res;
    });
    Perlbal::register_global_hook('manage_command.flush_stats', sub {
        my @res;
        push @res, sprintf "Flushing %d hits.", scalar @Stats;
        push @res, ".";
        flush_buffer();
        return \@res;
    });
    Perlbal::register_global_hook('manage_command.pause_stats', sub {
        my @res = ("Pausing stats...", ".");
        $Pause = 1;
        return \@res;
    });
    Perlbal::register_global_hook('manage_command.resume_stats', sub {
        my @res = ("Resuming stats...", ".");
        $Pause = 0;
        return \@res;
    });
    init_srand();
}
sub unload {
    Perlbal::unregister_global_hook('manage_command.hits');
    Perlbal::unregister_global_hook('manage_command.pause_stats');
    Perlbal::unregister_global_hook('manage_command.resume_stats');
    Perlbal::unregister_global_hook('manage_command.flush_stats');
    %Services = ();
    return 1;
}

sub register {
    my ($class, $svc) = @_;

    my $config_set = sub {
        my ($out, $what, $val) = @_;
        return 0 unless $what && $val;

        # setup an error sub
        my $err = sub {
            $out->("ERROR: $_[0]") if $out;
            return 0;
        };

        # see what they want to set and set it
        if ($what =~ /^max_size$/i) {
            $svc->{extra_config}->{hit_tracker_max_size} = $val;
        }
         else {
            return $err->("Plugin understands: max_size");
        }
    };

    $svc->register_setter('HitTracker', 'max_size', $config_set);
    my $start_http_request_hook =  sub {
        Perlbal::Plugin::HitTracker::handle_request($svc, $_[0]);
    };
    $svc->register_hook( hits => start_http_request => $start_http_request_hook );

    # mark this service as being active in this plugin
    $Services{"$svc"} = $svc;

    return 1;
}

sub handle_request { 
    my Perlbal::Service $svc = shift;
    my Perlbal::ClientProxy $client = shift;
    my Perlbal::HTTPHeaders $headers = $client->{req_headers};
    return 0 unless $headers;

    my $uri  = $headers->request_uri    || "";
    my $host = $headers->header('Host') || "";
    my ($user_id ) = $uri  =~ m{/(\d+)};
    my ($tweet_id) = $host =~ m{^(?:http://)?(\d+)\.data\.loudtwitter\.com};
    return 0 unless $user_id && $tweet_id;

    my $set_cookie = 0;
    my $code       = 200;
    my $cookie     = get_cookie($headers);
    unless ($cookie) {
        $cookie = generate_cookie();
        $set_cookie = 1;
    }

    if ($headers->header('If-Modified-Since')) {
        $code = 304;
    }

    my $res_headers = Perlbal::HTTPHeaders->new_response($code);
    my $ip          = $client->observed_ip_string || $client->peer_ip_string;
    my $referrer    = $headers->header('Referer');

    push @Stats, [ time, $tweet_id, $user_id, $cookie, $ip, $referrer ]
        unless $Pause;

    $res_headers->header('Set-Cookie' => 
        "lt=$cookie; expires=Wed, 28-Jan-2019 07:06:49 GMT; path=/; domain=.data.loudtwitter.com"
    ) if $set_cookie;

    $res_headers->header('Pragma' => 'no-cache');
    $res_headers->header('Content-Length' => bytes::length(GIFBIN));
    $res_headers->header('Content-Type' => 'image/gif');
    $res_headers->header('Cache-Control' => 'private, no-cache, no-cache="Set-Cookie", proxy-revalidate');
    $res_headers->header('Expires' =>  'Fri, 01 Aug 2008 14:53:00 GMT');
    $res_headers->header('Last-Modified' => 'Thu, 02 Feb 1978 08:15:00 GMT');
    $res_headers->header("Date", HTTP::Date::time2str(time()));
    $res_headers->header("P3P", 'CP="NOI DSP COR NID CUR DEVa OUR SAMa IND INT"');
    $client->setup_keepalive($res_headers);
    $client->state('xfer_resp'); ## why?
    $client->tcp_cork(1);
    $client->write($res_headers->to_string_ref);
    unless ($headers->request_method eq 'HEAD' or $code == 304) {
        # don't write body for head requests
        $client->write(\GIFBIN);
    }
    $client->write(sub { $client->http_response_sent; });

    flush_buffer_if_full($svc);
    return 1;
};

sub get_cookie {
    my $headers = shift;

    my %cookie;
    foreach (split(/;\s+/, $headers->header("Cookie") || '')) {
        next unless ($_ =~ /(.*)=(.*)/);
        $cookie{Perlbal::Util::durl($1)} = Perlbal::Util::durl($2);
    }
    return $cookie{'lt'};
}

sub generate_cookie {
    return int rand( 100_000_000_000 ); 
}

sub flush_buffer_if_full {
    my $svc = shift;
    my $limit = $svc->{extra_config}->{hit_tracker_max_size} || DEFAULT_MAX_SIZE;
    if (scalar @Stats >= $limit) {
        flush_buffer();
    }
}

sub flush_buffer {
    return unless @Stats;
    my $task = Gearman::Task->new(
        'flush_stats',
        \Storable::nfreeze({ stats => \@Stats }),
    );
    $gearman->add_task( $task );
    @Stats = ();
    #init_srand();
}

## blocking I think
sub init_srand {
    ## Strength => 0 to use urandom (see Crypt::Random manual)
    srand Crypt::Random::makerandom( Size => 32, Strength => 0 );
    return;
}

1;
