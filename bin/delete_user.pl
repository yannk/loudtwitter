#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';
use Twittary::Model::User;
use Twittary::API::User;

my $id = shift;

my $user = Twittary::API::User->find($id)
    or die "not found";

my $ret = Twittary::API::User->delete(user => $user);
if ($ret) {
    print "OK\n";
} else {
    print "NOT OK\n";
}
