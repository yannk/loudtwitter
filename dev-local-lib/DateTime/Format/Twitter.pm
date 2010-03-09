package DateTime::Format::Twitter;
use strict;
use warnings;
use DateTime::Format::Builder(
    parsers => {
        parse_datetime => [ {
            # Sun Jul 01 21:02:20 +0000 2007 
            params => [ qw( month day hour minute second time_zone year) ],
            regex  => qr/^\w+ (\w{3}) (\d{1,2}) (\d{2}):(\d{2}):(\d{2}) \+(\d{4}) (\d{4})$/,
            postprocess => \&fix,
        }],
    },
);

my $i = 1;
my %m2n = map { lc $_ => $i++ } (qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/);
sub fix {
    my %args = @_;
    $args{parsed}{month} = $m2n{ lc $args{parsed}{month} }; 
    return 1;
}
    
1;
