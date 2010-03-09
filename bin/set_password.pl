#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';
use Twittary::Model::User;
my $what = shift;
my $password = shift;

my $user = Twittary::Model::User->lookup($what)
    or die "Cannot find $what";
    
print "old is " . $user->password . "\n";
$user->password($password);
print "set " . ($user->update || "-"). "\n";
