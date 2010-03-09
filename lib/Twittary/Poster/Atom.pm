package Twittary::Poster::Atom;
use strict;
use warnings;

use base qw/Twittary::Poster/;
use XML::Atom::Client;
use XML::Atom::Entry;

sub id { 'atom' }

sub init {
    my $poster = shift;
    $poster->{client} = XML::Atom::Client->new;
}

# TODO
# add optional category
# detect and report incorrect login
sub transport {
    my $poster = shift;
    my(%param) = @_;

    my $PostURI = $poster->{endpoint};
    my $api = $poster->{client};
    $api->username($poster->{username});
    $api->password($poster->{password});
    $api->{ua}->max_size(10000);

    ## always track with this transport
    my $content = $param{content} || $poster->default_content;
    $content   .= ( $param{track} || "" );

    my $entry = XML::Atom::Entry->new(Version => 1.0);
    $entry->title($param{title} || "");
    $entry->content($content);
#    $entry->add_category({ term => "twitter" });
#    $entry->add_category({ term => "loudtwitter" });
    my $EditURI = $api->createEntry($PostURI, $entry);
    die $api->errstr unless $EditURI;
}

1;
