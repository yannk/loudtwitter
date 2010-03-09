package Twittary::TweetDriver;
use strict;
use warnings;

use Data::ObjectDriver::Driver::DBI;
use Data::YUID::Client;
use Twittary::DB;

sub driver {
    Data::ObjectDriver::Driver::DBI->new(
        %{ Twittary::DB->dsn },
        pk_generator => \&generate_pk,
    );
}

my $Instance;
sub yuid_instance {
    return $Instance ||=
        Data::YUID::Client->new(
            servers => [ '127.0.0.1' ],
        );
}

sub new_id {
    return yuid_instance()->get_id or die "cannot generate an id";
}

sub generate_pk {
    my $obj = shift;
    for my $pk (@{ $obj->primary_key_tuple }) {
        my $id = __PACKAGE__->new_id;
        $obj->$pk($id);
    }
    return 1;
}

1;
