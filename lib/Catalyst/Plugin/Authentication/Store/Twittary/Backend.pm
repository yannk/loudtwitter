package Catalyst::Plugin::Authentication::Store::Twittary::Backend;
use warnings;
use strict;

use Catalyst::Plugin::Authentication::Store::Twittary::User;
use Twittary::Model::AuthToken;
use Twittary::Model::User;

use base qw/Class::Accessor::Fast/;

sub from_session {
    my ( $self, $c, $id ) = @_;
    $self->get_user( $id );
}

sub get_user {
    my ( $self, $id, $hash ) = @_;

    my $user;
    if (ref $hash && (my $url = $hash->{url})) {
        $user =  Twittary::Model::AuthToken->lookup_by(
            token => 'openid_uri',
            value => $url,
        );
    } elsif ($hash) {
        ## assume this is a login password
        ## XXX yes I don't really know what I'm doing
        $user = Twittary::Model::AuthToken->lookup_by(
            token => 'email',
            value => $id,
        )
    }
    else {
        $user = Twittary::Model::User->lookup($id); 
    }
    return Catalyst::Plugin::Authentication::Store::Twittary::User->new($self, $user); 
}

sub user_supports {
    my $self = shift;
    return Catalyst::Plugin::Authentication::Store::Twittary::User->supports(@_);
}

1;
