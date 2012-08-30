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
use Term::ReadLine;
use List::Util qw[ max ];

=head1 USAGE

 ./draw.pl  

=head1 DESCRIPTION

Interactive test bing imagery

=head2 OPTIONS

=head1 AUTHOR

Alexander Sapozhnikov L<http://shoorick.ru/>, L<< E<lt>shoorick@cpan.orgE<gt> >>

=cut

my %seen;

sub neighbor {
    my ( $origin_text, $offset_x, $offset_y ) = @_;
    $origin_text =~ s/[^0-3]+//g;
    my $length = length $origin_text;
    my $origin = oct    $origin_text;

    my $x = $offset_x + cnv sprintf('%o', $origin      & 011111111111111111111), 2, 10;
    my $y = $offset_y + cnv sprintf('%o', $origin >> 1 & 011111111111111111111), 2, 10;

    return sprintf "%0${length}o", oct(sprintf '%b', $x) | oct(sprintf '%b', $y) << 1;

}

sub get_tile {
    my $ua    = shift;
    my $coord = shift;

    unless ( $seen{$coord} ) {
        my $response = $ua->get(
            sprintf( 'http://ant.dev.openstreetmap.org/bingimageanalyzer/tile.php?t=%s&force=1', $coord ),
            'Referer' => 'http://ant.dev.openstreetmap.org/bingimageanalyzer/?lat=55&lon=61&zoom=10',
        );
        $seen{$coord} = 1;
    }
}


my $ua = LWP::RobotUA->new('bing-imagery-checker/0.1', 'shoorick@cpan.org');
$ua->delay(1/600);

my $origin = $ARGV[0] || '12121011321002';

print STDERR "Commands: g[o] COORDS, f[ly] DX DY, d[raw] DX DY, q[uit]";

my $term = new Term::ReadLine 'draw-bing-coverage';
while ( defined ($_ = $term->readline('> ')) ) {

    last if /^bye|exit|q|quit$/;

    if ( /^go?\s+(\d+)/ ) {
        $origin = $1;
        next;
    }

    if ( /^f(ly)?\s+([-\d]+)\s+([-\d]+)/ ) {
        my ( $dx, $dy ) = ( $2, $3 );
        $origin = neighbor $origin, $dx, $dy;
        print STDERR "\nNew origin is $origin\n";
        next;
    }



    if ( /^d(raw)?\s+([-\d]+)\s+([-\d]+)/ ) {
        my ( $dx, $dy ) = ( $2, $3 );
        my $iterations = max( abs($dx), abs($dy) );
        next if $iterations == 0;

        print STDERR "Drawing...\n";
        for my $i ( 0 .. $iterations ) {
            get_tile( $ua, neighbor( $origin, $dx * $i / $iterations , $dy * $i / $iterations ) );
            print STDERR "\r$i / $iterations";
        }
        $origin = neighbor $origin, $dx, $dy;
        print STDERR "\nDone. New origin is $origin\n";
        next;
    }

    print STDERR "?";
}

