// lib/services/fg_task.dart
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import '../services/live_socket.dart';

class TrackTaskHandler extends TaskHandler {
  LiveSocket? _live;
  int? _reportId;
  int? _tecId;
  String _serverUrl = 'http://127.0.0.1:3001';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final rid = await FlutterForegroundTask.getData<int>(key: 'reportId');
    final tid = await FlutterForegroundTask.getData<int>(key: 'tecId'); // -1 si no hay
    final surl = await FlutterForegroundTask.getData<String>(key: 'serverUrl');

    _reportId = rid;
    _tecId = (tid != null && tid >= 0) ? tid : null;
    if (surl != null && surl.isNotEmpty) _serverUrl = surl;

    if (_reportId != null) {
      _live = LiveSocket()
        ..connect(
          serverUrl: _serverUrl,
          reportId: _reportId!,
          tecId: _tecId,
        );
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();
      if (!serviceEnabled ||
          perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_reportId != null) {
        _live?.sendLocation(lat: pos.latitude, lng: pos.longitude);
      }

      await FlutterForegroundTask.updateService(
        notificationTitle: 'Rastreando ruta (activo)',
        notificationText:
            'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}',
      );
    } catch (_) {
      // no-op
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool bySystem) async {
    _live?.dispose();
    _live = null;
  }
}
