#!/usr/bin/env perl

use Mojolicious::Lite;
use Mojo::UserAgent;
use Mojo::Cache;

use Geo::Coder::OSM;
use Geo::OSM::Tiles qw( :all );
use Math::BigInt;

my $ZOOM  = 14; # Minimal value for hirez Bing imagery

my $ua    = Mojo::UserAgent->new;
my $cache = Mojo::Cache->new( 'max_keys' => 1000 );


sub long_tile_number {
    my $x = Math::BigInt->from_oct( unpack 'B*', pack('N', shift) );
    my $y = Math::BigInt->from_oct( unpack 'B*', pack('N', shift) );
    my $zoom = shift || $ZOOM;

    $y->blsft(1);
    $y->bior($x);

    my $out = substr $y->as_oct, 1;
    return '0' x ($zoom - length $out) . $out;
} # sub long_tile_number 

sub check_tile {
    my $tile = shift;

    my $state = $cache->get( $tile );
    return $state if $state;

    # else not defined

    # calculate
    # $state = 'unknown';

    my $random = int rand 7;
    my $res = $ua->head( "http://ecn.t$random.tiles.virtualearth.net/tiles/a$tile.jpeg?g=587&n=z" )->res;

    $state
        = ( $res->headers->header('X-VE-Tile-Info') eq 'no-tile' )
        ? 'no'
        : 'yes';
#    X-VE-Tile-Info: no-tile


    $cache->set( $tile => $state );
    return $state;

} # sub check_long_tile_number




get '/' => sub {
  my $self = shift;
  $self->render('index');
};

any '/search' => sub {
    my $self = shift;
    my $geocoder = Geo::Coder::OSM->new(
#        'ua'    => $ua,
    );
    my @places = $geocoder->geocode(
        location => $self->param('address'),
    );

    my @tiles;

    foreach my $place ( @places ) {
        my $tilex = lon2tilex( $place->{'lon'}, $ZOOM);
        my $tiley = lat2tiley( $place->{'lat'}, $ZOOM);
        my $tile = long_tile_number( $tilex, $tiley, $ZOOM );
        push @tiles, {
            'tile'  => $tile,
            'class' => check_tile( $tile ),
        };
    }


    $self->render(
        'places' => \@places,
        'tiles'  => \@tiles,
    );

};


app->start;
__DATA__


@@ form.html.ep
%= form_for 'search' => begin
Search for
%= text_field 'address'
%= submit_button
% end


@@ index.html.ep
% layout 'default';
% title 'Welcome';
%= include 'form';

@@ search.html.ep
% layout 'default';

% my $map = $places->[0];
% if ( $map ) {
%    title 'Result';
%=   t 'h1' => 'Result';
<div id="map"></div>
<link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.4/leaflet.css" /><!--[if lte IE 8]>
<link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.4/leaflet.ie.css" /><![endif]--><script src="http://cdn.leafletjs.com/leaflet-0.4/leaflet.js"></script><script>
var map = L.map('map').setView([<%= $map->{'lat'} %>, <%= $map->{'lon'} %>], 16);
L.tileLayer('http://{s}.tile.cloudmade.com/894a23ab6e0944fa8097f1e803d062da/1175/256/{z}/{x}/{y}.png', {
    attribution: 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> Contributors, <a href="http://www.openstreetmap.org/copyright">ODbL 1.0</a>, Imagery &copy; <a href="http://cloudmade.com">CloudMade</a>', maxZoom: 18}).addTo(map);
var marker = L.marker([<%= $map->{'lat'} %>, <%= $map->{'lon'} %>]).addTo(map);
</script>
<ul class="places">
% for my $place ( @$places ) {
%   my $tile = shift @$tiles;
<li class="<%= $tile->{'class'} . ' class-' . $place->{'class'} . ' type-' . $place->{'type'} %>">
<a href="#" onclick="marker.setLatLng([<%= $place->{'lat'} %>, <%= $place->{'lon'} %>]);map.panTo([<%= $place->{'lat'} %>, <%= $place->{'lon'} %>])"><%= $place->{'display_name'} %></a>
</li>
% }
</ul>
% }
% else {
%    title 'Not Found';
%=   t 'h1' => 'Not Found';
% }

%= include 'form';

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title>
  <style>
  body { font-family: "PT Sans","Droid Sans","Liberation Sans",sans-serif; color: #000; background: #fff }
  a:link { color: #006 }
  a:visited { color: #303 }
  .unknown { background: #eee }
  .yes { background: #cfd }
  .no  { background: #fba }
  .places li:first-child { font-size: 150% }
  .places a { text-decoration: none }
  #map { height: 400px; width:50%; float:right }
  </style>
  </head>
  <body><%= content %></body>
</html>
