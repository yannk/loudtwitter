package Twittary::Form::User::PreferredPosting;
use strict;
use base 'Form::Processor::Model::DOD';

sub object_class { 'Twittary::Model::User' }

sub profile {
    my $self = shift;

    return {
        required => {
            preferred_posting_method  => 'Select',
        },
    };
}

sub options_preferred_posting_method {
    return map { $_ => $_ } qw/ email guest atom xmlrpc/;
}

1;
