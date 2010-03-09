package Twittary::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';
use Twittary::Form::User::PasswordReset;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

Twittary::Controller::Root - Root Controller for Twittary

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 default

=cut

sub default : Private {
    my($self, $c) = @_;
    $c->stash->{template} = 'notfound.tt';
}

#sub auto : Private {
#    my($self, $c) = @_;
#    use YAML; warn Dump $c->session;
#}

sub index : Private {
    my($self, $c) = @_;
    if ($c->user_exists) {
        unless ($c->user) {
            # XXX not very clean
            $c->session->{__user} = undef;
            $c->response->redirect('/');
            return;
        }
        if ($c->user->is_fully_registered) {
            $c->stash->{template} = 'home_member.tt';
        } else {
            $c->stash->{template} = 'home_loggedin_unreg.tt';
        }
    } else {
        $c->stash->{template} = 'home_loggedout.tt';
    }
}

sub indexhtml : Regexp('index.html?') {
    my($self, $c) = @_;
    $c->forward('index');
}

sub feedback : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'feedback.tt';
}

sub password : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'forgotten-password.tt';
}

sub reset_password : Regex('^reset-password/(\w+)/(\w+)$') {
    my($self, $c) = @_;
    eval {
        $c->session->{__user} = undef;
        $c->logout;
    };
    my ($shid, $code) = @{ $c->request->captures };
    my $user = Twittary::Model::User->lookup_by_shid($shid || 0);
    if ($user) {
        if ($user->email_challenge eq ($code || "")) {
            $c->stash->{template} = 'reset-password.tt';

            my $form = $c->stash->{form}
                     = Twittary::Form::User::PasswordReset->new;

            if ($c->request->method eq 'POST') {
                $form->validate($c->request->parameters);
                unless ($form->has_error) {
                    $user->password($form->field('password')->value);
                    $user->email_challenge(undef);
                    $user->update;
                    $c->set_authenticated(
                        Twittary::Model::User::Catalyst->wrap($user)
                    );
                    $c->response->redirect(
                        $c->uri_for('/', { password_updated => 1 })
                    );
                    return;
                }
            }
            return;
        }
    }
    $c->stash->{template} = 'error-invalid-user.tt';
}

sub ideas : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'feedback.tt';
}

sub signin_openid : Path('signin-openid') {
    my($self, $c) = @_;
    my $origin = $c->request->param('origin');
    if ($origin) {
        $c->session->{'openid_origin'} = $origin;
    } else {
        $origin = delete $c->session->{'openid_origin'} || '/';
    }
    my $success = eval { $c->authenticate_openid };
    if ($@) {
        warn $@;
        $c->response->redirect( $c->uri_for('/signin', { openid_claim_is_false => 1 }));
        return;
    }
    if ($success) {
        $c->response->redirect( $c->uri_for($origin, { openid_claim_is_true => 1 }) );
    }
}

sub about : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'about.tt';
}

sub support : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'support.tt';
}

sub signin : Local {
    my($self, $c) = @_;
    
    if ($c->request->method eq "POST") {
        my $success = $c->login( lc $c->request->param('email'), $c->request->param('password') );
        if ($success) {
            $c->response->redirect('/');
        } else {
            $c->response->redirect($c->uri_for('signin', { auth_failed => 1 }));
        }
    } else {
        $c->stash->{template} = 'signin.tt';
    }
    
}

sub signout : Local {
    my($self, $c) = @_;
    $c->logout;
    $c->response->redirect($c->uri_for('/'));
}


sub dumpme : Global {
    my($self, $c) = @_;
    $c->stash->{template} = 'dumpme.tt';
}

sub wait_confirm_email : Path('wait-confirm-email') {
    my($self, $c) = @_;
    $c->stash->{template} = 'wait-confirm-email.tt';
}

sub resend_email_confirmation : Path('resend-email-confirmation') {
    my($self, $c) = @_;

    my $email = lc $c->request->param('email');
    if ($c->request->method eq 'POST' && $email) {
        $c->stash->{email} = $email;
        my $user = Twittary::Model::User->lookup_by_email($email);
        if ($user) {
            if ($user->email_verified) {
                Twittary::API::User->email_already_verified($email);
            }
            else {
                Twittary::API::User->untrust_email($user);
            }
        }
        else {
            Twittary::API::User->email_not_found($email, 'confirmation');
        }
        $c->stash->{template} = 'email-sent.tt';
    }
    else {
        $c->stash->{template} = 'resend-email-confirmation.tt';
    }
}

sub forgotten_pass_email : Path('forgotten-pass-email') {
    my($self, $c) = @_;
    if ($c->request->method eq 'POST') {
        $c->stash->{email} = my $email = lc $c->request->param('email');
        my $user = Twittary::Model::User->lookup_by_email($email);
        if ($user) {
            Twittary::API::User->reset_password($user);
        }
        else {
            Twittary::API::User->email_not_found($email, 'password');
        }
        $c->stash->{template} = 'email-sent.tt';
    }
    else {
        $c->stash->{template} = 'forgotten-pass-email.tt';
    }
}

sub email_verify : Path('email-verify') {
    my($self, $c, $blob) = @_;
    $blob ||= $c->request->param('code');
    eval {
        throw Catalyst::Exception("Please specify a challenge")
            unless $blob;
        ## XXX display a form here, and post to this same endpoint

        my($code, $user_shid) = split /-/, $blob;

        my $user = Twittary::Model::User->lookup_by_shid($user_shid)
            or throw Catalyst::Exception("invalid code");

        eval {
            Twittary::API::User->verify_email(user => $user, code => $code);
        }; 
        if ($@) {
            throw Catalyst::Exception($@);
        } 
        else {
            $c->set_authenticated(
                Twittary::Model::User::Catalyst->wrap($user)
            );
            $c->response->redirect( $c->uri_for('/', { email => 'verified' }) );
        }
    }; if ($@) {
        $c->response->redirect( $c->uri_for('wait-confirm-email', { error => 1 }) );
    }
}

sub blog_compat : Path('blog-compat') {
    my($self, $c) = @_;
    $c->stash->{template} = 'blog-compat.tt';
}

sub tos : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'tos.tt';
}

sub atom_api_help : Path('atom-api-help') {
    my($self, $c) = @_;
    $c->stash->{template} = 'atom-api-help.tt';
}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {
#    my($self, $c) = @_;
#    use YAML; warn Dump ERROR => $c->error;
#    return unless @{ $c->error };
#    $c->stash->{template} = 'error.tt';
}

=head1 AUTHOR

pop,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
