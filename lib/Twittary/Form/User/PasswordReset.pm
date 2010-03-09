package Twittary::Form::User::PasswordReset;
use strict;
use base 'Form::Processor::Model::DOD';

sub object_class { 'Twittary::Model::User' }

sub profile {
    my $self = shift;
    return {
        required => {
            password    => { type => 'Password',  size => 100 },
            '2password' => { type => 'Text',      size => 100 },
        },
    };
}

sub validate_2password {
    my($self, $field) = @_;
    for (qw/ password 2password /) {
        return if $self->field($_)->errors;
    }
    $field->add_error('Passwords do not match')
        unless $field->value eq $self->field('password')->value;
}

1;
