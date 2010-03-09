package Twittary::Form::User::Email;
use strict;
use base 'Form::Processor::Model::DOD';

sub object_class { 'Twittary::Model::User' }

sub profile {
    my $self = shift;
    return {
        required => {
            endpoint_email  => { type => 'EmailSize', size => 200 },
        },
    };
}

1;
