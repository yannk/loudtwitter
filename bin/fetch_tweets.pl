#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use lib 'dev-local-lib';

use Twittary::API::User;
use Twittary::Importer;

use Getopt::Long;
GetOptions(
    "debug"  => \$Twittary::DEBUG,
);

my $user_info = shift || die "specify an user data";

my $user = Twittary::API::User->find($user_info)
    or die "cannot find user for $user_info";

Twittary::Importer->missing($user);
