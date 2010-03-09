package Twittary::Form::User::Atom;
use strict;
use base 'Form::Processor::Model::DOD';

sub object_class { 'Twittary::Model::User' }

sub profile {
    my $self = shift;

    return {
        required => {
            endpoint_user  => { type => 'Text', size => 255 },
            endpoint_atom  => { type => 'URL', size => 255 },
        },
        optional => {
            endpoint_pass => { type => 'Text', size => 255 },
        },
    };
}

1;
