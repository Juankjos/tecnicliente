// lib/widgets/map_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'route_polyline_layer.dart';

class MapView extends StatelessWidget {
  final MapController controller;
  final LatLng initialCenter;
  final double initialZoom;
  final List<Marker> markers;
  final List<LatLng> breadcrumb;
  final VoidCallback onMapReady;

  const MapView({
    super.key,
    required this.controller,
    required this.initialCenter,
    required this.initialZoom,
    required this.markers,
    required this.breadcrumb,
    required this.onMapReady,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 3,
        maxZoom: 19,
        onMapReady: onMapReady,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a','b','c'],
          userAgentPackageName: 'com.tuempresa.tecnicliente',
          maxZoom: 19,
          keepBuffer: 4, //Ayuda a que las baldozas, mejora fluidez
          errorTileCallback: (tile, error, stackTrace) {
          },
        ),
        MarkerLayer(markers: markers),
        PolylineLayer(polylines: [
          if (breadcrumb.length >= 2) Polyline(points: breadcrumb, strokeWidth: 4.0),
        ]),
        const RoutePolylineLayer(profile: 'driving'),
      ],
    );
  }
}
