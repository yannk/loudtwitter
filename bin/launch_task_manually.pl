#! perl
use strict;
use warnings;
use Find::Lib '../lib' => 'Twittary::Bootstrap';

use Storable();
use Gearman::Task;
use Gearman::Client;
use Twittary::Model::User;
use Twittary::Core;
use Getopt::Long;

my %opt = (type => 'fetch');
GetOptions(
    "user_id=s"      => \$opt{user_id},
    "twitter_name=s" => \$opt{twitter_name},
    "type=s"         => \$opt{type},
);

my $cfg    = Twittary::Core->config;
my $user;
if ($opt{twitter_name}) {
    ($user) = Twittary::Model::User->search({ twitter_name => $opt{twitter_name} });
}
else {
    $user = Twittary::Model::User->lookup($opt{user_id});
}
die "no such user" unless $user;
my $client = Gearman::Client->new(job_servers => [ @{$cfg->{GearmanServers}} ]);
my $task   = Gearman::Task->new(
    $opt{type},
    \Storable::nfreeze({
        user_id => $user->user_id,   
    }),
);

use Data::Dumper;
warn Dumper $client->do_task($task);
