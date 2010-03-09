package Twittary::Poster::XMLRPC;
use strict;
use warnings;

use base qw/Twittary::Poster/;

use RPC::XML;
use RPC::XML::Client;
#use RPC::XML::boolean;
$RPC::XML::ENCODING = 'UTF-8';

sub id { 'xmlrpc' }

sub init {
    my $poster = shift;
}

sub transport {
    my $poster = shift;
    my(%param) = @_;

    my $username = $poster->{username};
    my $password = $poster->{password};
    my $endpoint = $poster->{endpoint};

    my $client = RPC::XML::Client->new($endpoint);
    my $publish = RPC::XML::boolean->new(1);

    ## always track with xmlrpc
    my $content = $param{content} || $poster->default_content;
    $content   .= ( $param{track} || "" );

    my $post = {
        title       => $param{title}   || "",
        description => $content,
    };
    
    my $res = # eval { 
        $client->send_request('metaWeblog.newPost', '', $username, $password, $post, $publish);
#    };
#    Twittary::Log->log->info("first try post failed with $@");
#    unless ($res && ! $@) {
#        $res = $client->call('metaWeblog.newPost', '', $username, $password, $post, 1);
#    }

    die "Cannot post to $endpoint" unless defined $res; 
}

1;
