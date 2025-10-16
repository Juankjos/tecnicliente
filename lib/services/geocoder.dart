// lib/services/geocoder.dart
import 'package:latlong2/latlong.dart';

abstract class Geocoder {
  Future<LatLng> geocode(String address, {LatLng? fallback});
}
