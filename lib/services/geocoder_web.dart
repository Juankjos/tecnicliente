// lib/services/geocoder_web.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'geocoder.dart';

class WebGeocoder implements Geocoder {
  @override
  Future<LatLng> geocode(String raw, {LatLng? fallback}) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': raw, 'format':'jsonv2','limit':'1','addressdetails':'0',
        'accept-language':'es','countrycodes':'mx',
      });
      final headers = {'User-Agent': 'TVC-Rutas/1.0 (tvc.s34rch@gmail.com)'};
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final arr = (json.decode(res.body) as List?) ?? [];
        if (arr.isNotEmpty) {
          final m = arr.first as Map<String,dynamic>;
          final lat = double.tryParse('${m['lat']}');
          final lon = double.tryParse('${m['lon']}');
          if (lat != null && lon != null) return LatLng(lat, lon);
        }
      }
    } catch (_) {}
    return fallback ?? const LatLng(20.8169, -102.7635);
  }
}
