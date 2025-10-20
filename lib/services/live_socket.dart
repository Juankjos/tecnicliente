// lib/services/live_socket.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LiveSocket {
  IO.Socket? _s;
  final List<Map<String, dynamic>> _queue = [];

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
          // Importante: deja autoConnect por defecto (true). No llames _s!.connect() dos veces.
          .build(),
    );

    _s!.onConnect((_) {
      print('[live] connected id=${_s!.id}');
      _flushQueue();
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
      // Cola hasta que conecte
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
  }
}
