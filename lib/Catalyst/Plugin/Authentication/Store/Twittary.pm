package Catalyst::Plugin::Authentication::Store::Twittary;

use strict;
use warnings;

use Catalyst::Plugin::Authentication::Store::Twittary::Backend;

sub setup {
    my $c = shift;

    $c->default_auth_store(
        Catalyst::Plugin::Authentication::Store::Twittary::Backend->new
    );

    $c->next::method(@_);
}

1;
