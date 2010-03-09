package Form::Processor::Field::Twitter;
use strict;
use warnings;

use base qw/Form::Processor::Field::Text/;
use Twittary::Fetcher;

sub validate {
    my $field = shift;

    my $name = $field->input;
    if ($name) {
        if (lc $name eq 'loudtweeter') {
            $field->add_error(
                "Sorry! Please enter *your* twitter name"
            );
        }
        else {
            my $id = Twittary::Fetcher->verify_twitter_name($name);
            if (! $id) {
                $field->add_error(
                    "Sorry! $name doesn't look like a valid twitter account"
                );
            }
            elsif ($id < 0) {
                $field->add_error(
                    "Your updates are protected, I can't get them"
                );
            }
        }
    }
    return $field->SUPER::validate;
}

"tweet?";
