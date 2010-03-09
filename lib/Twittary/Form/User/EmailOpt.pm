package Twittary::Form::User::EmailOpt;
use strict;
use warnings;
use base 'Twittary::Form::User::EmailReq';

sub profile {
    my $form = shift;
    return {
        optional => {
            email       => { type => 'EmailSize', size => 200 },
            password    => { type => 'Password',  size => 100 },
            '2password' => { type => 'Text',      size => 100 },
        },
        dependency => [
            [ 'password', '2password', ],
            [ 'email', 'password', ], # TODO store the email elsewhere if we don't have a passsword
        ],
    };
}

## this is kinda a hack. If password then require email.
## It should nicely be builtin F::P (see my TODO)
sub validate_password {
    my($form, $field) = @_;
    my $email = $form->field('email');
    return if $email->value;
    $form->add_requires( $email );
    $email->required(1);
    $field->add_error('If password is specified, Email is required');
}

1;
