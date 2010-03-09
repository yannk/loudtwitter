package Twittary::Form::User::Twitter;
use strict;
use base 'Form::Processor::Model::DOD';

sub object_class { 'Twittary::Model::User' }

sub profile {
    my $self = shift;

    return {
        required => {
            twitter_name  => { type => 'Twitter' },
        },
    };
}

1;
