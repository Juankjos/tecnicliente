// lib/services/live_socket.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LiveSocket {
  IO.Socket? _s;
  final List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _pendingDest; // 👈 destino pendiente

  bool get isConnected => _s?.connected == true;

  void connect({
    required String serverUrl,
    required int reportId,
    required int? tecId,
  }) {
    if (_s != null) return;
    _s = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'reportId': '$reportId', 'tecId': tecId?.toString() ?? '', 'role': 'tech'})
          .enableReconnection()
          .build(),
    );

    _s!.onConnect((_) {
      print('[live] connected id=${_s!.id}');
      _flushQueue();
      // 👇 si había un destino pendiente, emitirlo ahora
      if (_pendingDest != null) {
        _s?.emit('destination:update', _pendingDest);
        print('[live] sent pending destination');
        _pendingDest = null;
      }
    });
    _s!.onConnectError((e) => print('[live] connect_error: $e'));
    _s!.onError((e) => print('[live] error: $e'));
    _s!.onDisconnect((_) => print('[live] disconnected'));
  }

  void _flushQueue() {
    if (!isConnected) return;
    for (final msg in _queue) {
      _s?.emit('location:update', msg);
    }
    if (_queue.isNotEmpty) {
      print('[live] flushed ${_queue.length} queued updates');
      _queue.clear();
    }
  }

  void sendDestination({
    required double lat,
    required double lng,
    String? address,
  }) {
    final payload = {'lat': lat, 'lng': lng, if (address != null) 'address': address};
    if (_s?.connected == true) {
      _s?.emit('destination:update', payload);
    } else {
      // 👉 guárdalo y lo mandamos al conectar
      _pendingDest = payload;
      print('[live] queued destination (will send on connect)');
    }
  }

  void sendLocation({
    required double lat,
    required double lng,
    double? speed,
    double? bearing,
    int? ts,
  }) {
    final payload = {
      'lat': lat,
      'lng': lng,
      if (speed != null) 'speed': speed,
      if (bearing != null) 'bearing': bearing,
      'ts': ts ?? DateTime.now().millisecondsSinceEpoch,
    };

    if (!isConnected) {
      _queue.add(payload);
      print('[live] queued update (socket not connected yet). queue=${_queue.length}');
      return;
    }
    _s?.emit('location:update', payload);
  }

  void dispose() {
    _s?.dispose();
    _s = null;
    _queue.clear();
    _pendingDest = null;
  }
}
