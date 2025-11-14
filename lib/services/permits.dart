// lib/services/permits.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class Permits {
  /// Pide permisos de notificaciones (Android 13+) y ubicación (incl. background).
  static Future<bool> requestLocationWithBackground() async {
    // Android 13+: notificaciones para poder mostrar la notificación del FGS
    final notif = await Permission.notification.request();
    if (!notif.isGranted && !notif.isLimited) {
      // Si niega notificaciones, muchos OEM matan el FGS. No forzamos, solo avisamos.
    }

    // Ubicación "cuando la app se usa"
    final loc = await Geolocator.requestPermission();
    if (loc == LocationPermission.deniedForever) {
      await openAppSettings();
      return false;
    }
    if (loc == LocationPermission.denied) {
      return false;
    }

    // Android 10+: background se pide por separado.
    // permission_handler expone Permission.locationAlways
    final bg = await Permission.locationAlways.request();
    if (!bg.isGranted) {
      // En algunos OEM, el sistema muestra un paso intermedio:
      // "Permitir siempre" aparece en configuración. Podemos abrir settings si lo niega.
      // await openAppSettings();
      // return false;
    }

    // Opcional: desactivar optimizaciones de batería
    // (evita que OEMs pausen el servicio)
    // await Permission.ignoreBatteryOptimizations.request();

    return true;
  }
}
