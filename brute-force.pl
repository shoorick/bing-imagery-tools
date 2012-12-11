#!/usr/bin/perl 
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

my $ua = LWP::RobotUA->new('bing-imagery-checker/0.1', 'shoorick@cpan.org');
$ua->delay(1/600);

my $origin = shift @ARGV || '12121011321002';
my $origin_length = length $origin;
my $spread = shift @ARGV || 2;
my %seen;


print STDERR
    'Checking... '
    . ( 4 ** $spread )
    ." sets of tiles to go\n";
for my $i ( 0 .. 4 ** $spread - 1 ) {
    for my $tail ( $origin_length + $spread .. 20 ) {
        my $coord
            = $origin
            . sprintf( "%0${spread}d", cnv( $i, 10, 4 ) )
            . '0' x ( 20 - $tail );
        unless ( $seen{$coord} ) {
            my $response = $ua->get(
                sprintf( 'http://ant.dev.openstreetmap.org/bingimageanalyzer/tile.php?t=%s&force=1', $coord ),
                'Referer' => 'http://ant.dev.openstreetmap.org/bingimageanalyzer/?lat=55&lon=61&zoom=10',
            );
            $seen{$coord} = 1;
            print STDERR "\rset $i, tile $coord ";
        } # unless seen
    } # for tail
} # for i

print STDERR "\nDone\n";

