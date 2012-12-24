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
        ? 'error'
        : 'success';
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

get  '/subscribe' => sub {};
post '/subscribe' => sub {};

app->start;

__DATA__

@@ form.html.ep
%= form_for 'search' => ( 'class' => 'navbar-form form-search pull-left' ) => begin
    %= t div => ( 'class' => 'input-append' ) => begin
        %= text_field 'address' => ( 'placeholder' => 'Search for place' ) => ( 'class' => 'search-query' )
        %= t 'button' => ( 'type' => 'submit' ) => ( 'class' => 'btn' ) => begin
            <i class="icon-search"></i>
        % end
    % end
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
<div class="span6"><div id="map"></div></div>
<div class="span6">
    <form action="subscribe" method="post">
        <table class="places table table-striped with-check">
            <tr>
                <th><input type="checkbox" id="title-checkbox" name="title-checkbox" /> </th>
                <th>See and subscribe</th>
            </tr>
% my %seen_at_this_page = ();
% my $checkbox_count = 0;
% for my $place ( @$places ) {
%   my $tile = shift @$tiles;
<tr class="<%= $tile->{'class'} . ' class-' . $place->{'class'} . ' type-' . $place->{'type'} . ( exists $seen_at_this_page{ $tile->{'tile'} } ? ' already' : '' ) %>">
<td>
% unless ( $tile->{'class'} eq 'success' || exists $seen_at_this_page{ $tile->{'tile'} } ) {
    %  $checkbox_count++;
    %= check_box 'tile-' . $tile->{'tile'} => $place->{'display_name'}
% }
</td>
<td><a href="#<%= $tile->{'tile'} %>" onclick="marker.setLatLng([<%= $place->{'lat'} %>, <%= $place->{'lon'} %>]);map.panTo([<%= $place->{'lat'} %>, <%= $place->{'lon'} %>])"><%= $place->{'display_name'} %></a>
</td>
%   $seen_at_this_page{ $tile->{'tile'} } = 1;
% }
</table>
% if ( $checkbox_count ) {
<button type="submit" class="btn btn-primary">Subscribe</button>
% }
% else {
<button type="submit" class="btn" disabled="disabled">Nothing to do</button>
<p>There is no uncovered placed. Try another query.</p>
% }
</form>
</div>
% }
% else {
%    title 'Not Found';
%= t h1 => 'Not Found';
% }


    <script src="http://cdn.leafletjs.com/leaflet-0.4/leaflet.js"></script>
    <script>
        var map = L.map('map').setView([<%= $map->{'lat'} %>, <%= $map->{'lon'} %>], 14);
        L.tileLayer('http://{s}.tile.cloudmade.com/894a23ab6e0944fa8097f1e803d062da/1155/256/{z}/{x}/{y}.png', {
            attribution: 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> Contributors, <a href="http://www.openstreetmap.org/copyright">ODbL 1.0</a>, Imagery &copy; <a href="http://cloudmade.com">CloudMade</a>', maxZoom: 18}).addTo(map);
        var marker = L.marker([<%= $map->{'lat'} %>, <%= $map->{'lon'} %>]).addTo(map);

        $(document).ready(function(){
            $("th input:checkbox").click(function() {
                var checkedStatus = this.checked;
                var checkbox = $(this).parents('.places').find('tr td:first-child input:checkbox');
                checkbox.each(function() {
                    this.checked = checkedStatus;
                    if (checkedStatus == this.checked) {
                        $(this).closest('.checker > span').removeClass('checked');
                    }
                    if (this.checked) {
                        $(this).closest('.checker > span').addClass('checked');
                    }
                });
            });
        });
    </script>


@@ subscribe.html.ep
% layout 'default';
% title 'Coming soon';
%= t 'h1' => 'Subscription';


@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title>
    <link href="/css/bootstrap.min.css" rel="stylesheet" media="screen">
    <link href="/css/bootstrap-responsive.css" rel="stylesheet">
    <link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.4/leaflet.css" />
    <!--[if lte IE 8]> <link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.4/leaflet.ie.css" /><![endif]-->
    <style>
      body { font-family: "PT Sans","Droid Sans","Liberation Sans",sans-serif }
      a:link { color: #006 }
      a:visited { color: #303 }
    /*  .table tbody tr.success td { background: #cfd }*/
      .table tbody tr.error   td { background: #fba }
      #map { height: 400px; /*width:50%; float:right*/ }
      .already td, li.already { font-size: 75%; color: #665 }
/*      .container-fluid { padding-right: 0; padding-left: 0; }
      .row-fluid [class*="span"] { margin-left: 0; }*/
    </style>
    <script src="http://code.jquery.com/jquery-latest.js"></script>
    <script src="/js/bootstrap.min.js"></script>
  </head>
  <body>
    <div class="navbar navbar-static-top">
      <div class="navbar-inner">
        <a class="brand" href="/" title="bing imagery &mdash; analyze and subscribe">bias</a>
        %= include 'form';
        <ul class="nav pull-right">
          <li><a href="/subscribe"><i class="icon-th-list"></i> Subscription</a></li>
          <li><a href="/profile"><i class="icon-user"></i> Profile</a></li>
          <li><a href="/logout"><i class="icon-off"></i> Logout</a></li>
        </ul>
      </div>
    </div>
      <div class="container-fluid">
          <div class="row-fluid">
              <%= content %>
          </div>
      </div>
  </body>
</html>
