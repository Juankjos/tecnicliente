// lib/services/geocoder_native.dart
import 'package:geocoding/geocoding.dart' as gc;
import 'package:latlong2/latlong.dart';
import 'geocoder.dart';

class NativeGeocoder implements Geocoder {
  @override
  Future<LatLng> geocode(String address, {LatLng? fallback}) async {
    try {
      final list = await gc.locationFromAddress(address);
      if (list.isNotEmpty) {
        final l = list.first;
        return LatLng(l.latitude, l.longitude);
      }
    } catch (_) {}
    return fallback ?? const LatLng(20.8169, -102.7635);
  }
}
