package Twittary::View::TT;

use strict;
use base 'Catalyst::View::TT';

use URI::Escape;

sub new {
    my $self = shift;
    $self->config({
        FILTERS => {
            loc => sub { $_[0] },
        },
        VARIABLES => {
            loc => sub { join ' ', @_ },
        },
    });
    $Template::Stash::SCALAR_OPS->{html} = \&Template::Filters::html_filter;
    $Template::Stash::SCALAR_OPS->{uri} = \&uri_filter;
    return $self->next::method(@_);
}

sub uri_filter {
    my $uri = shift;    
    #Encode::_utf8_on($uri);
    $uri = URI::Escape::uri_escape_utf8($uri);
    return $uri;
}   

=head1 NAME

Twittary::View::TT - Catalyst TT View

=head1 SYNOPSIS

See L<Twittary>

=head1 DESCRIPTION

Catalyst TT View.

=head1 AUTHOR

pop,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
