package Twittary::Form::User::Prefs;
use strict;
use base 'Form::Processor::Model::DOD';
use DateTime::TimeZone();
    
sub object_class { 'Twittary::Model::User' }

sub profile {
    my $form = shift;

    return {
        required => {
            post_hour   => 'Hour',
            post_minute => 'Minute',
        },
        optional => {
            name                     => { type => 'Text', size => 100 },
            post_prefix              => { type => 'Text', size => 500 },
            post_suffix              => { type => 'Text', size => 500 },
            post_title               => { type => 'Text', size => 255 },
            format_hide_time         => 'Checkbox',
            format_hide_replies      => 'Checkbox',
            format_hide_status_link  => 'Checkbox',
            format_only_lifetweets   => 'Checkbox',
            formatter_type           => 'Select',
            timezone                 => 'Select',
        },
    };
}

sub options_timezone {
    return map { $_ => $_ } DateTime::TimeZone::all_names;
}

sub options_formatter_type {
    return ( para => 'Paragraph', list => 'Bullet List' );
}

1;
