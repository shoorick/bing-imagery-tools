#!/usr/bin/perl -l 
#===============================================================================
#
#         FILE:  grab-bing-coverage.pl
#
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#      COMPANY:  South Ural State University
#      VERSION:  1.0
#      CREATED:  23.08.2012 21:37:32
#     MODIFIED:  $Id$ 
#===============================================================================

use strict;
use warnings;

use LWP::RobotUA;
use Math::BaseCnv;

=head1 USAGE

 ./grab-bing-coverage.pl  

=head1 DESCRIPTION

Test bing imagery

=head2 OPTIONS

=head1 AUTHOR

Alexander Sapozhnikov L<http://shoorick.ru/>, L<< E<lt>shoorick@cpan.orgE<gt> >>

=cut

sub neighbor {
    my ( $origin_text, $offset_x, $offset_y ) = @_;
    $origin_text =~ s/[^0-3]+//g;
    my $length = length $origin_text;
    my $origin = oct    $origin_text;

    my $x = $offset_x + cnv sprintf('%o', $origin      & 011111111111111111111), 2, 10;
    my $y = $offset_y + cnv sprintf('%o', $origin >> 1 & 011111111111111111111), 2, 10;

    return sprintf "%0${length}o", oct(sprintf '%b', $x) | oct(sprintf '%b', $y) << 1;

}

my $ua = LWP::RobotUA->new('bing-imagery-checker/0.1', 'shoorick@cpan.org');
$ua->delay(1/600);

my $MAX = 800;
my $origin = $ARGV[0] || '12121011321002';
my %seen;


print STDERR "Checking...\n";
for my $i ( 0 .. $MAX ) {
    my $coord = neighbor($origin, $i+cos($i/100)*20, -$i+sin($i/100)*20);
    unless ( $seen{$coord} ) {
        my $response = $ua->get(
            sprintf( 'http://ant.dev.openstreetmap.org/bingimageanalyzer/tile.php?t=%s&force=1', $coord ),
            'Referer' => 'http://ant.dev.openstreetmap.org/bingimageanalyzer/?lat=55&lon=61&zoom=10',
        );
        $seen{$coord} = 1;
    }

    print STDERR "\r$i of $MAX - $coord";
}

print STDERR "\nDone\n";

# print neighbor @ARGV;

