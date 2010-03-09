package Twittary;

use strict;
use warnings;

use Catalyst::Runtime '5.70';
use Catalyst::Log::Log4perl;
use Twittary::Core nolog => 1; # log is initd below

use base qw/Catalyst/;

our $VERSION = '0.01';

## init is done after using the ftrack.yaml
__PACKAGE__->config( Twittary::Core->config->{catalyst} );

my $log_config = __PACKAGE__->config->{log4perl} || "";
__PACKAGE__->log( Catalyst::Log::Log4perl->new(\$log_config) );

# Start the application
my @plugins = qw/
    ConfigLoader 
    Static::Simple 
    Authentication
    Authentication::Credential::OpenID
    Authentication::Credential::Password
    Authentication::Store::Twittary
    Session
    Session::Store::FastMmap
    Session::State::Cookie
    Form::Processor
/;
push @plugins, '-Debug' if $ENV{CATALYST_DEBUG};

# Start the application
__PACKAGE__->setup(@plugins);

our $DEBUG = 0;

sub finalize_error {
    my($c) = @_;
    
    if ($c->debug) {
        return $c->next::method(@_);
    }

    $c->response->content_type('text/html; charset=utf-8');
    $c->response->body(<<EOB);
We're sorry something unexpected happened...
EOB
    $c->response->status(500);
}

=head1 NAME

Twittary - Catalyst based application

=head1 SYNOPSIS

    script/twittary_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Twittary::Controller::Root>, L<Catalyst>

=head1 AUTHOR

pop,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;
