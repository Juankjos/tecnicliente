// lib/services/live_socket.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/chat_msg.dart';
import 'dart:async';

class LiveSocket {
  IO.Socket? _s;

  final List<Map<String, dynamic>> _queue = []; // cola de updates si aún no conectó
  Map<String, dynamic>? _pendingDest;           // destino pendiente

  final _chatCtrl = StreamController<ChatMsg>.broadcast();
  Stream<ChatMsg> get chatStream => _chatCtrl.stream;

  final List<ChatMsg> chatBuffer = <ChatMsg>[];

  bool get isConnected => _s?.connected == true;

  // Flags de primer ACK (garantiza que el primer dato realmente fue procesado)
  bool _firstLocationAcked = false;
  bool _firstDestAcked = false;

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
          .setQuery({
            'reportId': '$reportId',
            'tecId': tecId?.toString() ?? '',
            'role': 'tech',
          })
          .disableAutoConnect()      // 👈 controlamos cuándo conectar
          .enableReconnection()      // 👈 SÍ existe; reemplaza setReconnection(true)
          // .setReconnectionAttempts(999999)
          // .setReconnectionDelay(800)
          // .setReconnectionDelayMax(6000)
          .build(),
    );

    // --------- LISTENERS ---------
    _s!.onConnect((_) {
      print('[live] connected id=${_s!.id}');
      _flushQueue();
      if (_pendingDest != null) {
        _emitDestination(_pendingDest!);      // con ACK si es el primero
        print('[live] sent pending destination');
        _pendingDest = null;
      }
      _s?.emit('chat:history:get', {'limit': 50});
    });

    // Nota: en Dart, onConnect se dispara también tras reconectar.
    _s!.onConnectError((e) => print('[live] connect_error: $e'));
    _s!.onError((e) => print('[live] error: $e'));
    _s!.onDisconnect((reason) => print('[live] disconnected: $reason'));

    _s!.on('chat:message', (data) {
      try {
        final msg = ChatMsg.fromMap(Map<String, dynamic>.from(data ?? {}));
        chatBuffer.add(msg);
        _chatCtrl.add(msg);
      } catch (e) {
        print('[live] chat:message parse error $e');
      }
    });

    _s!.on('chat:history', (payload) {
      try {
        final list = (payload is List ? payload : <dynamic>[]).cast<dynamic>();
        final msgs = list
            .map((e) => ChatMsg.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        chatBuffer
          ..clear()
          ..addAll(msgs);
        for (final m in msgs) {
          _chatCtrl.add(m);
        }
      } catch (e) {
        print('[live] chat:history parse error $e');
      }
    });

    // 👇 Conecta al final (ya con todos los listeners listos)
    _s!.connect();
  }

  // --------- WRAPPERS con ACK para primer envío ---------
  void _emitLocation(Map<String, dynamic> payload) {
    if (!_firstLocationAcked) {
      _s?.emitWithAck('location:update', payload, ack: (res) {
        print('[live] ACK location:update => $res');
        _firstLocationAcked = true;
      });
    } else {
      _s?.emit('location:update', payload);
    }
  }

  void _emitDestination(Map<String, dynamic> payload) {
    if (!_firstDestAcked) {
      _s?.emitWithAck('destination:update', payload, ack: (res) {
        print('[live] ACK destination:update => $res');
        _firstDestAcked = true;
      });
    } else {
      _s?.emit('destination:update', payload);
    }
  }

  // --------- FLUSH COLA ---------
  void _flushQueue() {
    if (!isConnected) return;
    for (final msg in _queue) {
      _emitLocation(msg); // usa el wrapper (ACK para el primero)
    }
    if (_queue.isNotEmpty) {
      print('[live] flushed ${_queue.length} queued updates');
      _queue.clear();
    }
  }

  // --------- API PÚBLICA ---------
  void sendDestination({
    required double lat,
    required double lng,
    String? address,
  }) {
    final payload = {'lat': lat, 'lng': lng, if (address != null) 'address': address};
    if (isConnected) {
      _emitDestination(payload);
    } else {
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
    _emitLocation(payload); // usa wrapper
  }

  void sendChat({
    required int reportId,
    required int? tecId,
    required String text,
  }) {
    if (text.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'reportId': reportId,
      'from': 'tech',
      'senderId': tecId,
      'text': text.trim(),
      'ts': now,
    };
    _s?.emit('chat:send', payload);

    // Eco optimista
    final local = ChatMsg(
      reportId: reportId,
      from: 'tech',
      senderId: tecId,
      text: text.trim(),
      ts: now,
    );
    chatBuffer.add(local);
    _chatCtrl.add(local);
  }

  void requestHistory({int limit = 50}) {
    _s?.emit('chat:history:get', {'limit': limit});
  }

  void dispose() {
    try {
      _s?.off('chat:message');
      _s?.off('chat:history');
    } catch (_) {}
    _s?.dispose();
    _s = null;
    _queue.clear();
    _pendingDest = null;
    _firstLocationAcked = false;
    _firstDestAcked = false;
    _chatCtrl.close();
    chatBuffer.clear();
  }
}
