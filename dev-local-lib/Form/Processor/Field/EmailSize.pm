package Form::Processor::Field::EmailSize;
use strict;
use warnings;

use base qw/Form::Processor::Field::Email/;

use Rose::Object::MakeMethods::Generic (
    scalar => [
        size            => { interface => 'get_set_init' },
    ],
);

sub init_size { 0 }

sub validate {
    my $field = shift;

    # return if no size is set
    my $size = $field->size;
    if ($size) {
        my $value = $field->input;
        if (length $value > $size) {
            $field->add_error( 
                'Please limit to [quant,_1,character]. You submitted [_2]',
                $size, length $value,
            );
        }
    }
    return $field->SUPER::validate;
}

"siiiiize";
