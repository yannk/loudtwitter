package Twittary::Controller::User;
use strict;
use warnings;

use base 'Catalyst::Controller';

use DateTime::TimeZone();
use Twittary::API::User;
use Twittary::Form::User::PreferredPosting;

sub auto : Private {
    my($self, $c) = @_;
    unless ($c->user_exists) {
        # handle exceptions
        # throw Catalyst::Exception("Not allowed");
        $c->response->redirect($c->uri_for('/', { auth_req=> 1 }));
    }
    return 1;
}

sub twitter : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'user/twitter.tt';
    $c->forward('form');
}

sub email : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'user/email.tt';
    $c->forward('form');
}

sub atom : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'user/atom.tt';
    $c->forward('form');
    if ($c->form_posted) {
        # disable post using guest (ugly 2 UDPATE)
        if ($c->user->post_using_guest) {
            $c->user->post_using_guest(0);
            $c->user->update;
        }
    }
}

## copy paste XXX
sub xmlrpc : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'user/xmlrpc.tt';
    $c->forward('form');
    if ($c->form_posted) {
        # disable post using guest (ugly 2 UDPATE)
        if ($c->user->post_using_guest) {
            $c->user->post_using_guest(0);
            $c->user->update;
        }
    }
}

## ugly copy paste XXX
sub do_typepad_guest : Path('do-typepad-guest') {
    my($self, $c) = @_;
    $c->stash->{user} = $c->user;
    $c->stash->{template} = 'signup/typepad_guest.tt';
}

## ugly copy paste XXX
sub check_typepad_guest : Path('check-typepad-guest') {
    my($self, $c) = @_;
    my $user = $c->user;
    unless ($user->post_using_guest) {
        $c->response->redirect($c->uri_for('do-typepad-guest', { not_invited => 1 }));
    } else {
        $c->response->redirect($c->uri_for('/', { guest => 1 }));
    }
    return;
}

sub preferred_posting : Path('preferred-posting') {
    my($self, $c) = @_;
    throw Catalyst::Exception("tss tss")
        unless $c->request->method eq 'POST';
    my $form = Twittary::Form::User::PreferredPosting->new($c->user->user_id);
    $form->update_from_form($c->request->parameters);
    $c->user->reset_for_next_post;
    $c->response->redirect('/');
}

sub prefs : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'user/prefs.tt';
    $c->forward('load_timezones');
    my $orig_tz   = $c->user->timezone;
    my $orig_time = $c->user->post_time;
    $c->forward('form');
    my $user = $c->user;
    $user->refresh;
    if ($c->form_posted && (
            $orig_tz   ne $user->timezone
        ||  $orig_time ne $user->post_time
        )) {
        ## it has been updated... so recompute the next_post_date
        $user->adjust_post_time;
    }
}

sub load_timezones : Private { 
    my($self, $c) = @_;
    ## this is really a big list, should be sorted, even if there is 
    ## a javascript
    $c->stash->{all_timezones} = DateTime::TimeZone::all_names;
}

sub form : Private {
    my($self, $c) = @_;
    unless ($c->user) {
        throw Catalyst::Exception("you don't look authenticated");
    }
    $c->user->reset_for_next_post;
    $c->update_from_form($c->user->user_id);
}

sub suspend : Local {
    my($self, $c) = @_;
    throw Catalyst::Exception("tss tss")
        unless $c->request->method eq 'POST';
    $c->user->has_suspended(1);
    $c->user->update;
    $c->response->redirect($c->uri_for('/', { suspend => 1 }));
}

sub unsuspend : Local {
    my($self, $c) = @_;
    throw Catalyst::Exception("tss tss")
        unless $c->request->method eq 'POST';
    $c->user->reset_for_next_post;
    $c->user->has_suspended(0);
    $c->user->update;
    $c->response->redirect($c->uri_for('/', { unsuspend => 1 }));
}

sub delete : Local {
    my($self, $c) = @_;
    if ($c->request->method eq 'POST') {
        my $user = $c->user;
        if ($user) {
            eval {
                Twittary::API::User->delete(user => $user);
                $c->delete_session('user cancelled');
            };
        }
        $c->response->redirect($c->uri_for('/', { deleted => 1 })); 
    } else {
        $c->stash->{template} = 'user/delete.tt'; 
    }
}

sub test_setup : Path('test-setup') {
    my($self, $c) = @_;
    $c->stash->{template} = 'user/test-setup.tt'; 
    if ($c->request->method eq 'POST') {
        my $user = $c->user;
        if ($user) {
            my $err = Twittary::API::User->test_setup(user => $user);
            $c->stash->{post_error} = $err;
            $c->stash->{done}  = 1;
        }
    }
}

1;
