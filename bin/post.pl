#!/usr/bin/perl -w
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';

use Twittary::Model::User;
use Twittary::Model::Hit;
use Twittary::Poster;
use Twittary::Poster::XMLRPC;
use Twittary::Poster::Email;
use Twittary::Poster::Atom;
use Twittary::API::User;
use Twittary::Util;

use Getopt::Long;

my %defaults = (
    endpoint_atom => 'http://www.typepad.com/t/atom/weblog/blog_id=1344186', 
    endpoint_user => 'yann.kerherve', 
);

my %opts = ();
GetOptions(
    "email"             => \$opts{email},
    "atom"              => \$opts{atom},
    "xmlrpc"            => \$opts{xmlrpc},
    "debug"             => \$opts{debug},
    "endpoint_xmlrpc=s" => \$opts{endpoint_xmlrpc},
    "endpoint_email=s"  => \$opts{endpoint_email},
    "endpoint_atom=s"   => \$opts{endpoint_atom},
    "endpoint_user=s"   => \$opts{endpoint_user},
    "endpoint_pass=s"   => \$opts{endpoint_pass},
    "update_post_date"  => \$opts{update_post_date},
    "post_suffix=s"     => \$opts{post_suffix},
    "post_suffix_js"    => \$opts{post_suffix_js},
    "content=s"         => \$opts{content},
    "last10"            => \$opts{last10},
);

my $type = $opts{email} ? 'Email' : $opts{'xmlrpc'} ? 'XMLRPC' : $opts{'atom'} ? 'Atom' : 'Atom'; 

if ($opts{post_suffix_js}) {
    $opts{post_suffix} = <<EOJS;
<script type=\"text/javascript\">var gaJsHost = ((\"https:\" == document.location.protocol) ? \"https://ssl.\" : \"http://www.\");document.write(unescape(\"%3Cscript src='\" + gaJsHost + \"google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E\"));
</script>
<script type=\"text/javascript\">try {
    var pageTracker = _gat._getTracker(\"UA-66498-7\");
    pageTracker._trackPageview();
} catch(err) {}</script>
EOJS
}
my $pkg = "Twittary::Poster::$type";
my $id = shift;
$Data::ObjectDriver::DEBUG = $opts{debug};
my $user = Twittary::API::User->find($id);
die "no user " unless $user;
my $tweets = $user->daily_tweets || [];
if (! @$tweets && $opts{last10}) {
    my @tweets = Twittary::Model::Tweet->search({
        user_id => $user->user_id,
    },{ limit => 10, sort => 'created_at', direction => 'descend' });
    $tweets = \@tweets;
}
my $content = $opts{content};
unless ($content or @$tweets) {
    print STDERR "Nothing to do for " .  $user->twitter_name . ", no tweets\n";
    exit;
}

if ($content) {
    $content = $user->post_prefix . "\n\n$content";
}
else {
    $content = $user->formatter->process(
	    $tweets,
	    $user->twitter_name,
	    $user->post_prefix,
	    $opts{post_suffix} || $user->post_suffix,
    );
}
## it will sux if password is empty, but who need empty passwords anyway?

my $endpoint = $opts{endpoint_atom} 
            || $opts{endpoint_xmlrpc} 
            || $user->endpoint_atom 
            || $user->endpoint_xmlrpc
            || $defaults{endpoint_atom};
            
my $username = $opts{endpoint_user} || $user->endpoint_user || $defaults{endpoint_user};
my $password = $opts{endpoint_pass}  || $user->endpoint_pass;

my $poster = $pkg->new(
    email    => $opts{endpoint_email} || $user->endpoint_email,
    endpoint => $endpoint,
    username => $username,
    password => $password,
);

my $now = $user->next_post_date_obj;
$poster->post(content => $content);
$user->has_posted_on($now) if $opts{update_post_date};
