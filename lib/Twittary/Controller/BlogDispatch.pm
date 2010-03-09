package Twittary::Controller::BlogDispatch;
use strict;
use warnings;

use Twittary::Model::User;
use WWW::Blog::Metadata;

use base qw/Catalyst::Controller/;

sub default : Private {
    my($self, $c) = @_;
    unless ($c->request->method eq 'POST') {
        $c->response->redirect('/');
        return;
    }
    my $blog_uri = $c->request->param('blog_uri');
    unless ($blog_uri) {
        $c->response->redirect('/'); 
        return;
    }
    if (Twittary::Model::User->lookup_by_openid($blog_uri)) {
        $c->response->redirect($c->uri_for('/signin-openid', { claimed_uri => $blog_uri }));
        return;
    }
    $c->forward('blogid', [ $blog_uri ]);
}

sub blogid : Private {
    my($self, $c, $uri) = @_;
   
    my $meta = {};
    if ($uri =~ m/(vox|wordpress|livejournal)\.com/) {
        $meta = { openid_server => 1 };
    } else {
        $meta = WWW::Blog::Metadata->extract_from_uri($uri);
    }

    # add a blog_uri field in the user
    #my (@exists = Twittary::Model::User->

    $c->stash->{blog_uri} = $uri;
    $c->stash->{meta} = $meta;
    $c->stash->{template} = 'blogid.tt';
}

1;
