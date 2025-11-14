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

  // 👇 Nuevas propiedades para manejar el stream
  StreamSubscription<Position>? _posSub;
  Position? _lastPos;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Lee los datos guardados por FgService.start()
    final rid = await FlutterForegroundTask.getData<int>(key: 'reportId');
    final tid = await FlutterForegroundTask.getData<int>(key: 'tecId'); // -1 si no hay
    final surl = await FlutterForegroundTask.getData<String>(key: 'serverUrl');

    _reportId = rid;
    _tecId = (tid != null && tid >= 0) ? tid : null;
    if (surl != null && surl.isNotEmpty) _serverUrl = surl;

    print('[fg] onStart: reportId=$_reportId tecId=$_tecId serverUrl=$_serverUrl');

    // Levanta el socket si hay reporte
    if (_reportId != null) {
      _live = LiveSocket()
        ..connect(
          serverUrl: _serverUrl,
          reportId: _reportId!,
          tecId: _tecId,
        );
    }

    // Verifica servicios y permisos de ubicación
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final perm = await Geolocator.checkPermission();
    print('[fg] location enabled=$serviceEnabled perm=$perm');

    if (!serviceEnabled ||
        perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      print('[fg] sin permisos / GPS apagado al iniciar FGS');
      return;
    }

    // Configura el stream de ubicación
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best, // puedes bajar a medium si quieres ahorrar
      distanceFilter: 5, // mínimo 5 metros de diferencia para emitir
    );

    _posSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) async {
      _lastPos = pos;

      print('[fg-stream] '
          '${pos.latitude}, ${pos.longitude} @ ${pos.timestamp}');

      if (_reportId != null) {
        _live?.sendLocation(lat: pos.latitude, lng: pos.longitude);
      }

      // Actualiza la notificación con la última posición
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Rastreando ruta (activo)',
        notificationText:
            'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}',
      );
    }, onError: (e, st) {
      print('[fg-stream] error: $e');
      print(st);
    });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Este método ahora es más bien un "heartbeat" + fallback
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final perm = await Geolocator.checkPermission();

      if (!serviceEnabled) {
        print('[fg] onRepeatEvent: location service disabled');
        return;
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        print('[fg] onRepeatEvent: permission=$perm');
        return;
      }

      // Si el stream ya nos dio una posición, sólo refrescamos la notificación
      if (_lastPos != null) {
        final pos = _lastPos!;
        print('[fg] onRepeatEvent usando lastPos @ ${pos.timestamp}');
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Rastreando ruta (activo)',
          notificationText:
              'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}',
        );
        return;
      }

      // Fallback: intentar obtener una posición puntual
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _lastPos = pos;

      print('[fg] onRepeatEvent fallback -> '
          '${pos.latitude}, ${pos.longitude} @ ${pos.timestamp}');

      if (_reportId != null) {
        _live?.sendLocation(lat: pos.latitude, lng: pos.longitude);
      }

      await FlutterForegroundTask.updateService(
        notificationTitle: 'Rastreando ruta (activo)',
        notificationText:
            'Lat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}',
      );
    } catch (e, st) {
      print('[fg] error en onRepeatEvent: $e');
      print(st);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool bySystem) async {
    print('[fg] onDestroy bySystem=$bySystem');
    await _posSub?.cancel();
    _posSub = null;
    _live?.dispose();
    _live = null;
  }
}
