package Twittary::Model::AuthToken;
use strict;
use warnings;

use base qw( Data::ObjectDriver::BaseObject );

use Twittary::TweetDriver;
use Twittary::Model::User;

__PACKAGE__->install_properties({
    columns => [
        qw/token value user_id/ 
    ],
    datasource  => 'auth_token',
    primary_key => [ 'token', 'value' ],
    driver      => Twittary::TweetDriver->driver,
});

sub lookup_by {
    my $class = shift;
    my %params = @_;
    my $token = $params{token};
    my $value = $params{value};
    
    my($authtoken) = $class->search({ token => $token, value => $value });
    return unless $authtoken;
    return Twittary::Model::User->lookup($authtoken->user_id);
}

1;
