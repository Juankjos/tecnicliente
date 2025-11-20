// lib/services/push_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';

class PushService {
  static final PushService instance = PushService._();
  PushService._();

  /// Pide permiso de notificaciones (si hace falta) y devuelve el token FCM, o null.
  Future<String?> getTokenWithPermission() async {
    final messaging = FirebaseMessaging.instance;

    // Pedir permisos
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('[push] permiso de notificación denegado');
      return null;
    }

    final token = await messaging.getToken();
    print('[push] FCM token = $token');
    return token;
  }
}
