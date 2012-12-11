#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  benchmark-conversion.pl
#
#      COMPANY:  South Ural State University
#      VERSION:  1.0
#      CREATED:  10.12.2012 23:29:15
#     MODIFIED:  $Id$ 
#===============================================================================

use strict;
use warnings;

=head1 USAGE

 ./compare-conversion.pl  

=head1 DESCRIPTION

Compare speed of conversion methods
for 3-component OSM Tile numbers (tile/tile/zoom) set to single tile number for Bing Virtual Earth

=head2 OPTIONS

=head1 AUTHOR

Alexander Sapozhnikov L<http://shoorick.ru/>, L<< E<lt>shoorick@cpan.orgE<gt> >>

=cut

use Benchmark qw/ cmpthese /;
use Math::BaseCnv;
# use Math::BigInt; # already used by Math::BaseCnv

sub via_cnv {
    my $sum
        =   cnv(cnv(cnv(shift, 10, 2), 4, 2), 2, 10)
        + ( cnv(cnv(cnv(shift, 10, 2), 4, 2), 2, 10) << 1 );

    my $zoom = shift;

    return
        sprintf "%0${zoom}d", cnv($sum, 10, 4);
} # sub via_cnv

sub via_cnv8 {
    my $sum
        =   cnv(cnv(shift, 10, 2), 8, 2)
        + ( cnv(cnv(shift, 10, 2), 8, 2) << 1 );
        # Warning: Overflow

    my $zoom = shift;

    return
        sprintf "%0${zoom}o", $sum;
} # sub via_cnv8

sub via_bigint {
#    my $x = Math::BigInt->from_oct( cnv(shift, 10, 2) );
#    my $y = Math::BigInt->from_oct( cnv(shift, 10, 2) );
    my $x = Math::BigInt->from_oct( unpack 'B*', pack('N', shift) );
    my $y = Math::BigInt->from_oct( unpack 'B*', pack('N', shift) );
    my $zoom = shift;

    $y->blsft(1);
    $y->bior($x);

    my $out = $y->as_oct;
    return '0' x ($zoom - length $out) . $out;
}

sub by_digits_array {
    my ( $x, $y, $zoom ) = @_;
    my @x_digits = split '', sprintf( "%0${zoom}b", $x );
    my @y_digits = split '', sprintf( "%0${zoom}b", $y );

    my $out = '';

    do {
        $out .= shift(@x_digits) + ( shift( @y_digits ) << 1 );
    } while scalar @x_digits;

    return $out;
} # sub by_digits_array

sub by_digits_substr {
    my ( $xdec, $ydec, $zoom ) = @_;
    my $x = sprintf( "%0${zoom}b", $xdec );
    my $y = sprintf( "%0${zoom}b", $ydec );

    my $out = '';

    while ( 1 ) {
        my $digit = substr( $x, 0, 1, '' );
        last
            if $digit eq '';

        $out
            .=    $digit
            + ( substr( $y, 0, 1, '' ) << 1 );
    }

    return $out;
} # sub by_digits_substr

sub via_oct {
    my ( $x, $y, $zoom ) = @_;

    # Warning: Octal number > 037777777777 non-portable
    return sprintf "%0${zoom}o", oct(sprintf '%b', $x) | oct(sprintf '%b', $y) << 1;
} # sub via_oct




my @params = (10987, 6543, 14);

print
    "\ncnv:     ", via_cnv(   @params ),
    "\ncnv8:    ", via_cnv8(   @params ),
    "\nbigint   ", via_bigint(   @params ),
    "\noct:     ", via_oct(   @params ),
    "\nA digit: ", by_digits_array( @params ),
    "\nS digit: ", by_digits_substr( @params ),
    "\n";


cmpthese(1e8,
    {
        'BaseCnv' => via_cnv(   @params ),
        'BigInt'  => via_bigint(   @params ),
#        'oct'           => via_oct(   @params ),
        '@array'  => by_digits_array( @params ),
        '$substr' => by_digits_substr( @params ),
    }
);


