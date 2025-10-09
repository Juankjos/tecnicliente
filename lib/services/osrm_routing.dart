// lib/services/osrm_routing.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const OsrmRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class OsrmRouting {
  /// profile: driving | walking | cycling
  static Future<OsrmRoute?> route({
    required LatLng from,
    required LatLng to,
    String profile = 'driving',
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/$profile/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&alternatives=false&steps=false',
    );

    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('OSRM ${res.statusCode}: ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    if ((data['code'] ?? '') != 'Ok') return null;

    final routes = (data['routes'] as List?) ?? const [];
    if (routes.isEmpty) return null;

    final r0 = routes.first as Map<String, dynamic>;
    final geom = (r0['geometry'] as Map)['coordinates'] as List;
    final pts = geom
        .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    return OsrmRoute(
      points: pts,
      distanceMeters: (r0['distance'] as num).toDouble(),
      durationSeconds: (r0['duration'] as num).toDouble(),
    );
  }
}
