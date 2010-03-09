package Twittary::Form::User::EmailReq;
use strict;
use base 'Form::Processor::Model::DOD';

sub object_class { 'Twittary::Model::User' }

sub profile {
    my $self = shift;
    return {
        required => {
            email       => { type => 'EmailSize', size => 200 },
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

sub validate_email {
    my($self, $field) = @_;
    return if $field->errors;
    my $email = $field->format_value;
    return unless $email;
    if ($self->object_class->lookup_by_email($email)) {
        $field->add_error("Sorry, this email is already associated with an account");
    }
    return;
}

1;
