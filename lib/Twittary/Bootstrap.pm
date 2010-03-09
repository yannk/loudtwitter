package Twittary::Bootstrap;
use strict;
use warnings;
use lib;
use Cwd();
use File::Spec::Functions qw( rel2abs catdir splitdir );

# XXX DUPE. Extract that on cpan, for xsake
our $Base;
our $Imported = 0;

sub import {
    my $class = shift;
    return if $Imported;
    $class->setup_inc;
    $Imported++;
}

sub base {
    my $class = shift; 
    return $Base if $Base;
    my $base = $INC{'Twittary/Bootstrap.pm'};

    my @paths = splitdir( Cwd::realpath( rel2abs $base ));
    splice @paths, -3; ## remove /lib/Twittary/Bootstrap.pm
    $base = catdir @paths;
    $Base = $base;
    return $Base;
}

sub setup_inc {
    my $class = shift;
    my $base = $class->base;
    ## since we use Find::Lib 'lib' is already imported. The annoying thing with
    ## that is that dev-local-lib comes after it. XXX we should delete it from 
    ## %INC and re-add it again
    my @paths = map { catdir( $base, $_)  } qw/ dev-local-lib /;
    lib->import( @paths );
}

1;
