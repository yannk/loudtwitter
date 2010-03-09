package Catalyst::Plugin::Authentication::Store::Twittary::User;

use strict;
use warnings;

use base qw/Catalyst::Plugin::Authentication::User Class::Accessor::Fast/;

BEGIN { __PACKAGE__->mk_accessors(qw/user store/) }
use overload '""' => sub { shift->id }, fallback => 1;

sub supported_features {
    return {
        password => {
            self_check => 1,
            clear => 1,
        },
        session => 1,
        roles => 1,
    };
}

sub id { 
    my $user = shift;
    return $user->user->user_id
}

sub new {
    my ( $class, $store, $user ) = @_;
    return unless $user;
    return bless { store => $store, user => $user }, $class;
}

sub for_session {
    my $self = shift;
    return $self->id;
}

sub AUTOLOAD {
    my $self = shift;
    ( my $method ) = ( our $AUTOLOAD =~ /([^:]+)$/ );
    return if $method eq "DESTROY";
    $self->user->$method(@_);
}


1;
