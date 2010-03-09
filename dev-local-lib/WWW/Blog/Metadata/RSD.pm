package WWW::Blog::Metadata::RSD;
use strict;

use WWW::Blog::Metadata;
WWW::Blog::Metadata->mk_accessors(qw( rsd_uri ));
use URI;

sub on_got_tag {
    my $class = shift;
    my($meta, $tag, $attr, $base_uri) = @_;
    if ($tag eq 'link' && $attr->{rel} =~ /\bEditURI\b/i &&
        $attr->{type} eq 'application/rsd+xml') {
        $meta->rsd_uri(URI->new_abs($attr->{href}, $base_uri)->as_string);
    }
}
sub on_got_tag_order { 99 }

1;
