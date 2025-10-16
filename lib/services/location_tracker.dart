// lib/services/location_tracker.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationTracker {
  StreamSubscription<Position>? _sub;
  final _streamCtrl = StreamController<LatLng>.broadcast();

  Stream<LatLng> get stream => _streamCtrl.stream;
  bool get isRunning => _sub != null;

  Future<void> start({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 10,
  }) async {
    if (_sub != null) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }
    final ok = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
    if (!ok) throw Exception('Permiso de ubicación no concedido');

    final settings = LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      _streamCtrl.add(LatLng(pos.latitude, pos.longitude));
    }, onError: (e) {
      // Puedes propagar error si quieres
    });
  }

  Future<LatLng?> current() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _streamCtrl.close();
  }
}
