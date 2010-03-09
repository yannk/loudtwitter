#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';
use Twittary::API::User;
use Twittary::Model::User;

my $user = Twittary::Model::User->lookup(shift)
    or die "cannot find user";
use YAML;
print Dump $user;
print "are you sure you want to delete? (y/N)";
read STDIN, my $ans, 1;
if (lc $ans eq 'y') {
    Twittary::API::User->delete( user => $user );
    print "done\n";
}
