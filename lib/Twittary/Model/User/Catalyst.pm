package Twittary::Model::User::Catalyst;
use strict;
use warnings;

use Twittary::Model::User;
use Twittary::Model::AuthToken;
use Catalyst::Plugin::Authentication::Store::Twittary::User;

sub new {
    my $class = shift;
    my $hash = shift;
    my $url = $hash->{url};
    my $user = Twittary::Model::AuthToken->lookup_by(token => 'openid_uri', value => $url);
    return $class->wrap($user) if $user;

    ## XXX to move in another class?
    $user = Twittary::Model::User->new;
    $user->save;
    my $user_id = $user->user_id;
    my $authtoken = Twittary::Model::AuthToken->new;
    $authtoken->user_id($user_id);
    $authtoken->token('openid_uri');
    $authtoken->value($url);
    $authtoken->save;
    return $class->wrap($user);
}

sub wrap {
    my $class = shift;
    my $user = shift;
    my $store = 'Catalyst::Plugin::Authentication::Store::Twittary::Backend'; 
    return Catalyst::Plugin::Authentication::Store::Twittary::User->new($store, $user);
}

1;
