package Twittary::BlogDetector;
use strict;
use warnings;


sub detect {
    my($class, $uri) = @_;
    $class->clean(\$uri);

    return 'typepad'   if $uri =~ m{typepad\.(\w{2,3})}o;
    return 'vox'       if $uri =~ m{\.vox\.com}o;
    return 'wordpress' if $uri =~ m{\.wordpress\.com}o;
    return 'livejournal' if $uri =~ m{\.livejournal\.}o;

    ## XXX do more advanced detecting by fetching content
    ## typepad ip detection ? (faster)
    #204.9.176.0 - 204.9.183.255 
}

sub clean {
    my $class = shift;
    my $uriref = shift;
    $$uriref =~ s{^http://}{};
    $$uriref =~ s{/+$}{};
    return;
}
    
1;
