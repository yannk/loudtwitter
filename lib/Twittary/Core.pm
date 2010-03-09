package Twittary::Core;
use strict;
use warnings;

use Twittary::Bootstrap;
use File::Basename;
use File::Spec();
use Log::Log4perl;
use YAML::Syck;
use Twittary::Bootstrap;

our $Config;
our $Logger;

sub import {
    my $class = shift;
    my %param = @_;
    $class->load_logger unless $Logger or $param{nolog};
}

__PACKAGE__->load_config unless $Config;

sub log {
    my $caller = (caller)[0];
    return Log::Log4perl::get_logger( $caller );
}

sub logfile {
    my $class = shift;
    my $file  = shift || _logfile_from_progname();
    return File::Spec->catfile($class->logdir, "$file.log");
}

sub logdir {
    my $class = shift;
    my $logdir = $class->config->{logdir};
    return $logdir if $logdir;
    return File::Spec->catdir(Twittary::Bootstrap->base, 'logs');
}
sub _logfile_from_progname {
    (my $file = File::Basename::basename($0)) =~ s/[^\w\.\-]//g;
    ($file) = $file =~ /(\w+)/s;  ## Untaint.
    return $file;
}

sub load_logger {
    my $class = shift;
    my $config = $class->config;
    my $log4perl = $config->{log4perl};
    return Log::Log4perl->init(\$log4perl);
}

sub config {
    my $class = shift;
    $Config ||= $class->load_config;
    return $Config;
}

sub load_config {
    my $class  = shift;
    my $config = {};
    for (qw/ twittary.yaml prod.yaml /) {
        _merge($config, $class->load_config_file($_));
    }
    return $config;
}

sub load_config_file {
    my $class    = shift;
    my $filename = shift;
    my $base     = Twittary::Bootstrap->base;
    my $file     = File::Spec->catfile( $base, 'conf', $filename );
    return {} unless -f $file;
    my $data     = YAML::Syck::LoadFile($file);
    return $data;
}

sub _merge {
    my($config, $new) = @_;
    return unless $new;
    for (keys %$new) {
        $config->{$_} = $new->{$_};
    }
}

1;
