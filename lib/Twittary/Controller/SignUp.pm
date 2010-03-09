package Twittary::Controller::SignUp;

use strict;
use warnings;
use base 'Catalyst::Controller';

use Form::Processor;

use Twittary::API::User;
use Twittary::BlogDetector;
use Twittary::Fetcher;
use Twittary::Form::User::Email;
use Twittary::Form::User::Atom;
use Twittary::Form::User::Twitter;
use Twittary::Form::User::Prefs;
use Twittary::Form::User::EmailReq;
use Twittary::Form::User::EmailOpt;
use Twittary::Importer;
use Twittary::Model::User::Catalyst;
use Twittary::Core;
use WWW::Blog::Metadata;

=head1 NAME

Twittary::Controller::Register - Register our soon to be users

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 default

=cut

sub auto : Private {
    my($self, $c) = @_;
    if ($c->user_exists) {
        if ($c->user->is_fully_registered) {
            $c->response->body("you are signed-in!");
            return 0;
        } 
    }
    return 1;
}

sub index : Private {
    my($self, $c) = @_;
    if (my $uri = $c->request->param('blog_uri')) {
        $c->session->{register} = {};
        $c->session->{register}{blog_uri} = $uri;
        $c->detach('blog_detector');
    }
    $c->forward('what_s_your_blog');
}

sub what_s_your_blog : Path('what-s-your-blog') {
    my($self, $c) = @_;

    ## start afresh 
    $c->session->{register} = {};

    ## our form 
    ## XXX too strict?
    my $h = $c->user_exists ? { blog_uri => $c->user->openid_uri } : {};
    my $form = $c->stash->{form} = Form::Processor->new(
        profile => {
            required => {
                blog_uri => { type => 'Text', size => 255 },
            },
        },
        init_object => $h,
    );
    $c->stash->{template} = 'signup/blog.tt';
    if ($c->form_posted) {
        $form->validate($c->request->parameters);
        $c->session->{register}{blog_uri} = $form->field('blog_uri')->value;
        unless ($form->has_error) {
            $c->forward('blog_detector');
        }
    }
}

sub from_openid : Path('use-openid-uri') {
    my($self, $c) = @_;
    $c->session->{register}{blog_uri} = $c->user->openid_uri;
    $c->forward('blog_detector');
}

sub blog_detector : Private {
    my($self, $c) = @_;
    
    my $uri = $c->session->{register}{blog_uri};
    my $type = Twittary::BlogDetector->detect($uri) || "generic";
    $c->session->{register}{blog_type} = $type;
    $c->response->redirect($c->uri_for("blog-$type"));
# XXX I need an auto templating action... or something (?)
# # priority is to launch though :)
}

sub blog_typepad : Path('blog-typepad') {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/atom.tt';
    $c->forward(form => [ 'Twittary::Form::User::Atom', 'twitter' ]);
    unless ($c->form_posted) {
        my $blog_uri = $c->session->{register}{blog_uri};
        if ($blog_uri) {
            eval {
                # XXX don't do that at each reload 
                $blog_uri = "http://$blog_uri" unless $blog_uri =~ m{^.{3,5}://};
                my $meta = WWW::Blog::Metadata->extract_from_uri($blog_uri)
                    or die WWW::Blog::Metadata->errstr;
                $c->stash->{metadata} = $meta;
                if (my $rsd_uri = $meta->rsd_uri) {
                    my($host, $blog_id) = $rsd_uri =~ m{^http://([^/]+)/.*?(\d+)};
                    my $tp_atom = "http://$host/t/atom/weblog/blog_id=$blog_id";
                    $c->stash->{guess_tp_atom} = $tp_atom;
                    $c->stash->{form}->field('endpoint_atom')->value($tp_atom);
                }
            };
            if($@) {
                Twittary::Core->log->warn("tp blog extract:" .$@);
            }
        }
    }
}

sub wants_guest : Path('wants-guest') {
    my($self, $c) = @_;
    $c->session->{register}{do_typepad_guest} = 1; 
    $c->response->redirect($c->uri_for('twitter'));
}

sub do_typepad_guest : Path('do-typepad-guest') {
    my($self, $c) = @_;
    $c->stash->{user} = Twittary::Model::User->lookup($c->session->{register}{user_id});
    $c->stash->{template} = 'signup/typepad_guest.tt';
}

sub check_typepad_guest : Path('check-typepad-guest') {
    my($self, $c) = @_;
    my $user = Twittary::Model::User->lookup($c->session->{register}{user_id})
        or throw Catalyst::Exception("no saved user");
    unless ($user->post_using_guest) {
        $c->response->redirect($c->uri_for('do-typepad-guest', { not_invited => 1 }));
    } else {
        $c->forward('post_save');
    }
    return;
}

sub blog_vox : Path('blog-vox') {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/email.tt';
    $c->forward(form => [ 'Twittary::Form::User::Email', 'twitter' ]);
}

sub blog_livejournal : Path('blog-livejournal') {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/atom.tt';
    $c->forward(form => [ 'Twittary::Form::User::Atom', 'twitter' ]);
    unless ($c->form_posted) {
        my $blog_uri = $c->session->{register}{blog_uri};
        if ($blog_uri) {
            my $lj_atom = "http://www.livejournal.com/interface/atom/post";
            $c->stash->{guess_lj_atom} = $lj_atom;
            $c->stash->{form}->field('endpoint_atom')->value($lj_atom);
        }
    }
}

sub blog_generic : Path('blog-generic') {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/atom.tt';
    $c->forward(form => [ 'Twittary::Form::User::Atom', 'twitter' ]);
}

sub blog_wordpress : Path('blog-wordpress') {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/xmlrpc.tt';
    $c->forward(form => [ 'Twittary::Form::User::Xmlrpc', 'twitter' ]);
    unless ($c->form_posted) {
        my $blog_uri = $c->session->{register}{blog_uri};
        if (my $wp_xmlrpc = $blog_uri) {
            $wp_xmlrpc = "http://$wp_xmlrpc" unless $wp_xmlrpc =~ m{^.{3,5}://};
            $wp_xmlrpc .= "/" unless $wp_xmlrpc =~ m{/$};
            $wp_xmlrpc .= "xmlrpc.php";
            $c->stash->{guess_wp_xmlrpc} = $wp_xmlrpc;
            $c->stash->{form}->field('endpoint_xmlrpc')->value($wp_xmlrpc);
        }
    }
}

sub twitter : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/twitter.tt';
    if ($c->form_posted) {
        ## save the twitter_id as well
        ## FIXME: double api request
        my $name = $c->request->param('twitter_name'); 
        $c->session->{register}{twitter_id}
            = Twittary::Fetcher->verify_twitter_name($name);
    }
    $c->forward(form => [ 'Twittary::Form::User::Twitter', 'prefs' ]);
}

sub prefs : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/prefs.tt';
    $c->forward(form => [ 'Twittary::Form::User::Prefs', 'email-auth' ]);
    unless ($c->form_posted) {
        $c->forward('Twittary::Controller::User', 'load_timezones');
        ## how could I do that nicely
        $c->stash->{form}->field('post_suffix')->value('Automatically shipped by <a href="http://www.loudtwitter.com">LoudTwitter</a>');
    }
}

sub email : Local {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/email.tt';
    $c->forward(form => [ 'Twittary::Form::User::Email', 'twitter' ]);
}

sub email_auth : Path('email-auth') {
    my($self, $c) = @_;
    $c->stash->{template} = 'signup/email_auth.tt';
    my $form_class = $c->user_exists && $c->user->openid_uri 
                   ? 'Twittary::Form::User::EmailOpt'
                   : 'Twittary::Form::User::EmailReq';
    $c->forward(form => [ $form_class, 'save' ]);
}

## XXX this is what I'd like to do:
#sub form for blog_typepad : Local {
#    my($self, $c) = @_;
#    $c->stash->{template} = 'form/atom.tt';
#    my $fake_obj = { item => $c->session->{register}, item_id => 'temp' };
#    my $form = Twittary::Form::User::Atom->new($fake_obj);
#    if ($c->form->posted) {
#        $form->update_from_form($c->request->parameters);
#        unless ($form->has_error) {
#            $c->response->redirect($c->uri_for('twitter'));
#            use YAML; warn Dump $c->session->{register};
#        }
#    }
#}

sub form : Private {
    my($self, $c, $pkg, $next) = @_;
    my $form = $c->stash->{form} = $pkg->new;
    if ($c->form_posted) {
        $form->validate($c->request->parameters);
        unless ($form->has_error) {
            for my $field ($form->fields) {
                $c->session->{register}{$field->name} = $field->format_value;
            }
            $c->response->redirect($c->uri_for($next));
        }
    }
}

sub save : Local {
    my($self, $c) = @_;
    my $data = $c->session->{register};
    my $user = $c->user_exists ? $c->user : Twittary::Model::User->new;
    my @interesting = qw/post_hour post_minute  post_suffix post_title
                         twitter_name twitter_id endpoint_email endpoint_atom 
                         endpoint_xmlrpc timezone
                         endpoint_user endpoint_pass password name/;
    my %values = map { $_ => $data->{$_} } @interesting;
    $user->set_values(\%values);
    $user->has_suspended(0);
    $user->created_on(DateTime->now);
    $user->save;
    $user->adjust_post_time;

    $c->session->{register}{user_id} = $user->user_id;

    if ($data->{do_typepad_guest}) {
        $c->detach('do_typepad_guest');
    }
    $c->forward('post_save');
}
    
sub post_save : Local {
    my($self, $c) = @_;
    ## insert email auth token if present
    my $email = $c->session->{register}{email};
    my $user = Twittary::Model::User->lookup($c->session->{register}{user_id})
        or throw Catalyst::Exception("User hasn't been saved?");

    if ($email) {
        eval {
            $user->add_token(email => $email);
        }; if ($@) {
            throw Catalyst::Exception("Duplicate email $email");
        }
        Twittary::API::User->untrust_email($user);
        $c->response->redirect($c->uri_for('/wait-confirm-email'));
    } else {
        $c->response->redirect($c->uri_for('/', { registration => 'complete'}));
    }
    return;
}

1;
