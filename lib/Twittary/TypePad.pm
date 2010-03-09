package Twittary::TypePad;
use strict;
use warnings;

use List::Util qw/first/;
use LWP::UserAgent;
use Twittary::Core;
use Twittary::API::User;

use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors('stack');

sub GUEST_USER  { Twittary::Core->config->{typepad}{guest}{user} || 'twittary' };
sub GUEST_PASS  { Twittary::Core->config->{typepad}{guest}{pass} || 'password' };

sub tp_app { 
    my $self = shift;
    return $self->stack eq 'jp'
           ? "https://www.typepad.jp/t/app"
           : "http://www.typepad.com/t/app";
}

sub atom_uri { 
    my $self = shift;
    my $blog_id = shift || 0;
    if ($blog_id =~ /^6a/) {
        return "http://www.typepad.com/services/atom/svc=blogs/blog_id=$blog_id";
    }
    return $self->stack eq 'jp'
           ? "https://www.typepad.jp/t/atom/weblog/blog_id=$blog_id"
           : "http://www.typepad.com/t/atom/weblog/blog_id=$blog_id";
}

sub accept_invite {
    my $self = shift;
    my $textref = shift;
    my $ilink = $self->extract_invite_link($textref);
    unless ($ilink) {
        Twittary::Core->log->error("Faulty message: $$textref");
        Twittary::API::User->fucked_invite;
        die "No ilink"; 
    }
    $self->stack('jp') if $ilink =~ /typepad.jp/;
## tp beta
    #    <form method="post" action="http://www.typepad.com/t/app">
    #    <input type="hidden" name="__mode" value="redir" />
    #    <input type="hidden" name="next" value="http://www.typepad.com/services/join_blog/6p00e551b972ed8834-ekdogrbd" />
    my $ua = LWP::UserAgent->new;
    use HTTP::Cookies;
    my $jar = HTTP::Cookies->new;
    $ua->cookie_jar($jar);
    $ua->env_proxy;

        
#    if (my ($invite_code) = $ilink =~ m!join_blog/([\w-]+)! ) {
    if ( $ilink =~ m!join_blog/([\w-]+)! ) {
        return $self->tp2($ilink)
    }
    my($session_id) = $ilink =~ m/session_id=(\w+)/;
    unless ($session_id) {
        my $response = $ua->get($ilink);
        my $webcontent = $response->is_success ? $response->content : "";
        ($session_id) = $webcontent =~ m/name="session_id" value="([^"]+)"/;
        unless ($session_id) {
            Twittary::Core->log->error("Faulty message or web page: $$textref $webcontent");
            Twittary::API::User->fucked_invite;
            die "No session id";
        }
    }
    ## let's login first
    my $tp_app = $self->tp_app();
    my $response = $ua->post($tp_app, { 
          username => GUEST_USER(),
          password => GUEST_PASS(),
    }); 
    
    $response = $ua->post($tp_app, { 
        __mode => 'accept',
        session_id => $session_id,
    });
    my $code = $response->code;
    die "unexpected response from accept (code $code)" unless $code eq 302;
    my $redirect_uri = $response->header('Location');
    my($blog_id) = $redirect_uri =~ /\?added=(\d+)/;
    return $blog_id;
}

sub tp2_app { "http://www.typepad.com/services/signin" }

sub tp2 {
    my $self   = shift;
    my $ilink  = shift;

    my $accept = $ilink . "/accept";

    my $ua = LWP::UserAgent->new;
    use HTTP::Cookies;
    my $jar = HTTP::Cookies->new;
    $ua->cookie_jar($jar);
    $ua->env_proxy;

    ## let's login first
    my $tp2_app  = $self->tp2_app();
    my $response = $ua->post($tp2_app, { 
          username => GUEST_USER(),
          password => GUEST_PASS(),
    }); 

    ## now accept it
    $response = $ua->post($accept);
    my $code = $response->code;
    die "unexpected response from accept (code $code)" unless $code eq 302;
    my $redirect_uri = $response->header('Location');
    # http://www.typepad.com/site/blogs?added_blog=6a00d8354c047469e2010536784ab4970c
    my($blog_id) = $redirect_uri =~ /added_blog=(\w+)/;
    return $blog_id;
}

# http://www.typepad.com/services/join_blog/6p00d8354c047469e2-zdawqerd
sub extract_invite_link {
    my $self = shift;
    my $textref = shift;
    my $links = $self->extract_all_links($textref);
    return first { /(invite|join_blog)/ } @$links;
}

sub extract_all_links {
    my $self = shift;
    my $textref = shift;
    my @links;
    while ($$textref =~ m{(https?://\S+)}g) {
        push @links, $1;
    }
    return \@links;
}

1;
